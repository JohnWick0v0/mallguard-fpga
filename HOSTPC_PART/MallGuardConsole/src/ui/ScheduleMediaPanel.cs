// MallGuard 商场多媒体与应急显示终端 · Windows控制台
// 职责：电脑时段计划、素材管理、Flash保存和观察记录；调度依赖实时串口连接。
// 保留V5.1类/方法标识以兼容现有测试，文件名按产品职责组织。
using System;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace MallDisplayConsole {
 public sealed partial class MainForm {
  public static bool ExperienceSmokeEnabled;
  SchedulePlan schedule=new SchedulePlan();CheckBox scheduleEnabled;DateTimePicker[] scheduleTimes;
  Label scheduleStatus,loadingStatus,observationStatus;ProgressBar loadProgress;DataGridView commandGrid;
  readonly System.Diagnostics.Stopwatch scheduleArmWatch=new System.Diagnostics.Stopwatch();int armedSlot=-1;
  int? lastManual;int scheduleAttempt=-1;readonly Observation observation=new Observation();StreamWriter observationCsv;string observationBase;
  int demoSlot=-1,demoLoadTicks,demoSaveTicks,experienceStep;DateTime experienceStart,demoLoadStarted;bool demoQueuedSlot;
  Control BuildExperience(){
   try{string p=Path.Combine(root,"data","schedule.json");if(File.Exists(p)){SchedulePlan saved=new JavaScriptSerializer().Deserialize<SchedulePlan>(File.ReadAllText(p,Encoding.UTF8));if(saved!=null&&saved.IsValid)schedule=saved;}}catch{}
   Panel page=new Panel{Dock=DockStyle.Fill,AutoScroll=true,Padding=new Padding(10),BackColor=Color.White};
   TableLayoutPanel rows=new TableLayoutPanel{Dock=DockStyle.Top,Height=485,ColumnCount=1,RowCount=7};foreach(int h in new[]{37,40,43,44,34,34,220})rows.RowStyles.Add(new RowStyle(SizeType.Absolute,h));page.Controls.Add(rows);
   FlowLayoutPanel times=new FlowLayoutPanel{Dock=DockStyle.Fill,WrapContents=false};scheduleEnabled=new CheckBox{Text="启用电脑时段调度",AutoSize=true,Margin=new Padding(0,8,12,0)};times.Controls.Add(scheduleEnabled);scheduleTimes=new DateTimePicker[4];int[] starts={schedule.Morning,schedule.Noon,schedule.Evening,schedule.Default};string[] captions={"早间","午间","晚间","默认"};
   for(int i=0;i<4;i++){times.Controls.Add(new Label{Text=captions[i],AutoSize=true,Margin=new Padding(0,9,4,0)});DateTimePicker d=new DateTimePicker{Format=DateTimePickerFormat.Custom,CustomFormat="HH:mm",ShowUpDown=true,Width=70,Value=DateTime.Today.AddMinutes(starts[i]),Margin=new Padding(0,4,12,0)};scheduleTimes[i]=d;times.Controls.Add(d);d.ValueChanged+=delegate{ReadSchedule();};}
   scheduleEnabled.CheckedChanged+=delegate{scheduleAttempt=-1;armedSlot=-1;scheduleArmWatch.Restart();ReadSchedule();scheduleStatus.Text=scheduleEnabled.Checked?"已启用：使用电脑本地时间；断开连接时停止发送。":"自动时段调度已关闭，SW2/SW3 和手动选择有效。";};rows.Controls.Add(times,0,0);
   scheduleStatus=Theme.Label("默认关闭。上拨=0；拨动SW2/SW3会暂停自动调度，重新勾选后恢复。",9,Theme.Muted);scheduleStatus.Dock=DockStyle.Fill;rows.Controls.Add(scheduleStatus,0,1);
   FlowLayoutPanel manual=new FlowLayoutPanel{Dock=DockStyle.Fill,WrapContents=false};for(int i=0;i<4;i++){int slot=i;Button b=Button(new[]{"00 默认","01 早间","10 午间","11 晚间"}[i],Theme.Blue,false);b.Width=98;b.Height=30;b.Click+=delegate{if(scheduleEnabled.Checked)scheduleEnabled.Checked=false;SendCommand("slot "+slot,true);};manual.Controls.Add(b);}Button retry=Button("重新按计划投放",Theme.Blue,false);retry.Width=145;retry.Height=30;retry.Click+=delegate{scheduleAttempt=-1;if(!scheduleEnabled.Checked)scheduleEnabled.Checked=true;};manual.Controls.Add(retry);rows.Controls.Add(manual,0,2);
   FlowLayoutPanel actions=new FlowLayoutPanel{Dock=DockStyle.Fill,WrapContents=false};Button media=Button("素材检查 / 转换",Theme.Blue,true);media.Width=145;media.Height=30;media.Click+=delegate{using(MediaForm f=new MediaForm(root,prefs.Assets))f.ShowDialog(this);};actions.Controls.Add(media);Button save=Button("保存配置到Flash",Theme.Blue,false);save.Width=145;save.Height=30;save.Click+=delegate{SendCommand("save",true);};actions.Controls.Add(save);
   Button export=Button("导出操作记录",Theme.Blue,false);export.Width=130;export.Height=30;export.Click+=delegate{ExportCommands();};actions.Controls.Add(export);Button observe=Button("开始2小时观察",Theme.Blue,false);observe.Width=140;observe.Height=30;observe.Click+=delegate{StartObservation();};actions.Controls.Add(observe);Button end=Button("结束并导出",Theme.Blue,false);end.Width=110;end.Height=30;end.Click+=delegate{StopObservation();};actions.Controls.Add(end);rows.Controls.Add(actions,0,3);
   Panel progressPanel=new Panel{Dock=DockStyle.Fill};loadProgress=new ProgressBar{Dock=DockStyle.Right,Width=210,Maximum=100};loadingStatus=Theme.Label("等待设备加载状态",9,Theme.Navy);loadingStatus.Dock=DockStyle.Fill;loadingStatus.AutoEllipsis=true;progressPanel.Controls.Add(loadingStatus);progressPanel.Controls.Add(loadProgress);rows.Controls.Add(progressPanel,0,4);
   observationStatus=Theme.Label("观察未开始。需实物连续运行满2小时并覆盖四时段、视频、四类应急和寻人/寻物；演示数据不能通过实物验收。",8.5f,Theme.Muted);observationStatus.Dock=DockStyle.Fill;rows.Controls.Add(observationStatus,0,5);
   commandGrid=Grid();foreach(string c in new[]{"时间","操作","阶段","详情"})commandGrid.Columns.Add(c,c);commandGrid.Columns[3].FillWeight=220;rows.Controls.Add(commandGrid,0,6);
   return page;
  }
  void ReadSchedule(){if(scheduleTimes==null||scheduleTimes[3]==null)return;SchedulePlan p=new SchedulePlan{Morning=scheduleTimes[0].Value.Hour*60+scheduleTimes[0].Value.Minute,Noon=scheduleTimes[1].Value.Hour*60+scheduleTimes[1].Value.Minute,Evening=scheduleTimes[2].Value.Hour*60+scheduleTimes[2].Value.Minute,Default=scheduleTimes[3].Value.Hour*60+scheduleTimes[3].Value.Minute};
   if(!p.IsValid){if(scheduleEnabled!=null)scheduleEnabled.Checked=false;if(scheduleStatus!=null)scheduleStatus.Text="四个起点必须按早间、午间、晚间、默认递增。";return;}schedule=p;scheduleAttempt=-1;
   if(!smoke)try{string dir=Path.Combine(root,"data");Directory.CreateDirectory(dir);File.WriteAllText(Path.Combine(dir,"schedule.json"),new JavaScriptSerializer().Serialize(schedule),Encoding.UTF8);}catch(Exception e){AddLog("WARN","时段设置保存失败："+e.Message,null);}
  }
  void TrackCommand(string command,string phase,string detail){if(commandGrid==null)return;commandGrid.Rows.Add(DateTime.Now.ToString("HH:mm:ss.fff"),command,phase,detail);while(commandGrid.Rows.Count>500)commandGrid.Rows.RemoveAt(0);}
  void ExportCommands(){using(SaveFileDialog d=new SaveFileDialog{Filter="CSV|*.csv",FileName="操作记录.csv"}){if(d.ShowDialog(this)!=DialogResult.OK)return;StringBuilder b=new StringBuilder("时间,操作,阶段,详情\r\n");foreach(DataGridViewRow row in commandGrid.Rows){foreach(DataGridViewCell cell in row.Cells)b.Append('"').Append(Convert.ToString(cell.Value).Replace("\"","\"\"")).Append("\",");b.Length--;b.Append("\r\n");}File.WriteAllText(d.FileName,b.ToString(),new UTF8Encoding(true));}}
  void ReceiveExperience(BoardState s){
   if(s.Version>=25){if(lastManual.HasValue&&lastManual.Value!=s.ManualCounter&&scheduleEnabled.Checked){scheduleEnabled.Checked=false;scheduleStatus.Text="SW2/SW3已手动接管；自动调度已暂停，请重新勾选恢复。";TrackCommand("SW2/SW3","手动接管","停止电脑自动时段发送");}lastManual=s.ManualCounter;}
   if(observation.Running){observation.Feed(s);if(observationCsv!=null){observationCsv.WriteLine(String.Join(",",new[]{s.ReceivedUtc.ToString("O"),s.Sequence.ToString(),s.Slot.ToString(),s.Picture.ToString(),s.Emergency.ToString(),s.NoticeKind.ToString(),s.Volume.ToString(),s.Brightness.ToString(),s.Error.ToString("X2"),s.VideoError.ToString("X2"),s.LoadFlags.ToString("X2"),s.LoadProgress.ToString(),s.HasLoadDetail?s.LoadStage.ToString("X2"):"",s.HasLoadDetail?s.LoadFile.ToString("X2"):"",s.HasLoadDetail?s.LoadError.ToString("X2"):"",s.HasLoadDetail?s.LoadElapsedSeconds.ToString():""}));if(observation.Frames%20==0)observationCsv.Flush();}}
  }
  void UpdateExperience(){
   if(loadingStatus==null)return;
   bool capable=Fresh&&state.Version>=25;
   loadProgress.Value=state==null?0:state.Version>=25?(state.BootReady&&!state.Loading&&!state.LoadFailed?100:Math.Max(0,Math.Min(100,state.LoadProgress))):state.BootReady?100:0;
   loadingStatus.Text=!Fresh?"等待实时状态":state.Version<25?"当前为旧协议；完整功能需配套V25固件":state.LoadFailed?"加载失败，保留可用缓存；请选择时段重试":state.Loading?"后台加载 "+state.LoadProgress+"% · "+(state.CachedFrame?"保留上一完整画面":"正在缓存当前画面"):!state.BootReady?"启动加载中":"当前素材已就绪";
   if(state!=null&&state.HasLoadDetail)loadingStatus.Text=(Fresh?"":"[历史状态] ")+Protocol.LoadDetail(state);
   tips.SetToolTip(loadingStatus,Protocol.LoadDetail(state));
   loadingStatus.ForeColor=state!=null&&state.LoadFailed?Color.FromArgb(190,58,54):Theme.Navy;
   if(scheduleEnabled.Checked&&!guided.Running){
    if(!capable)scheduleStatus.Text="自动调度等待配套固件的实时状态。";
    else if(pending!=null||finderBusy||state.Emergency!=0||state.NoticeKind!=0||state.VideoMode||state.Loading||state.ConfigBusy||!state.BootReady)scheduleStatus.Text="自动调度等待广告界面空闲；不打断视频、应急或广播。";
    else{int target=schedule.SlotAt(DateTime.Now);if(armedSlot!=target){armedSlot=target;scheduleArmWatch.Restart();}
     if(scheduleArmWatch.ElapsedMilliseconds<1000){scheduleStatus.Text="核对最新板端状态后投放，物理拨码可接管。";}
     else if(state.Slot==target&&!state.LoadFailed)scheduleStatus.Text="计划投放："+new[]{"默认","早间","午间","晚间"}[target]+" · "+DateTime.Now.ToString("HH:mm:ss");
     else if(scheduleAttempt!=target){scheduleAttempt=target;SendCommand("slot "+target,true);}
     else scheduleStatus.Text="该时段已发送过请求；若未生效，请检查原因并点击重新投放。";
    }
   }
   if(observation.Running){double seconds=observation.ElapsedSeconds;observationStatus.Text=(observation.Demo?"离线演示观察":"实物串口观察")+" · "+TimeSpan.FromSeconds(Math.Max(0,seconds)).ToString(@"hh\:mm\:ss")+" / 02:00:00 · 状态 "+observation.Frames+" 帧 · 错误 "+observation.ErrorFrames;if(seconds>=7200)StopObservation();}
  }
  void StartObservation(){if(!Fresh){AddLog("WARN","先连接设备并等待有效状态，或使用明确标记的离线演示。",null);return;}if(observation.Running){AddLog("INFO","观察已在进行。",null);return;}
   observation.Start(DateTime.UtcNow,demo);string dir=smoke?captureDir:Path.Combine(root,"data","observations");Directory.CreateDirectory(dir);observationBase=Path.Combine(dir,(demo?"demo_":"physical_")+DateTime.UtcNow.ToString("yyyyMMdd_HHmmss_fff"));observationCsv=new StreamWriter(observationBase+".csv",false,new UTF8Encoding(true));observationCsv.WriteLine("utc,sequence,slot,picture,emergency,notice,volume,brightness,error,video_error,load_flags,load_percent,load_stage,load_file,load_low_error,load_elapsed_seconds");AddEvent("开始"+(demo?"离线演示":"实物串口")+"2小时观察");}
  void StopObservation(){if(!observation.Running)return;object result=observation.Summary(DateTime.UtcNow);observation.Running=false;if(observationCsv!=null){observationCsv.Dispose();observationCsv=null;}File.WriteAllText(observationBase+".json",new JavaScriptSerializer().Serialize(result),Encoding.UTF8);observationStatus.Text="观察已导出："+observationBase+".json；未满2小时或覆盖不完整时不会标记通过。";}
  void DemoExperienceCommand(string command){
   if(demoState==null)return;int code=Protocol.CommandCode(command);if(code<0)return;
   demoState.ReceiptSequence=(demoState.ReceiptSequence+1)&255;demoState.ReceiptCommand=code;demoState.ReceiptStatus=0;
   bool slot=command.StartsWith("slot ",StringComparison.Ordinal);
   if(code<0x20&&!slot&&(demoState.Emergency!=0||demoState.Loading||demoState.ConfigBusy)){demoState.ReceiptStatus=1;return;}
   if((command=="next"||command=="prev")&&demoState.VideoMode){demoState.ReceiptStatus=2;return;}
   if(slot){int n;if(Int32.TryParse(command.Substring(5),out n)&&n>=0&&n<=3){demoSlot=n;demoQueuedSlot=demoState.VideoMode||demoState.Emergency!=0||demoState.NoticeKind!=0;demoState.ReceiptStatus=demoQueuedSlot?5:0;if(!demoQueuedSlot){demoState.Slot=n;demoState.LoadFlags=3;demoState.LoadProgress=1;demoState.LoadStage=1;demoState.LoadFile=0;demoState.LoadError=0;demoState.LoadElapsedSeconds=0;demoLoadStarted=DateTime.UtcNow;demoLoadTicks=12;}}}
   else if(command=="save"){demoState.ConfigFlags=9;demoSaveTicks=5;}
  }
  void DemoExperienceTick(){
   if(demoQueuedSlot&&!demoState.VideoMode&&demoState.Emergency==0&&demoState.NoticeKind==0){demoQueuedSlot=false;demoState.Slot=demoSlot;demoState.LoadFlags=3;demoState.LoadProgress=1;demoState.LoadStage=1;demoState.LoadFile=0;demoState.LoadError=0;demoState.LoadElapsedSeconds=0;demoLoadStarted=DateTime.UtcNow;demoLoadTicks=12;}
   if(demoLoadTicks>0){demoState.LoadElapsedSeconds=(int)Math.Min(65535,Math.Max(0,(DateTime.UtcNow-demoLoadStarted).TotalSeconds));if(demoState.Emergency!=0||demoState.NoticeKind!=0){demoState.LoadStage=8;}else{demoLoadTicks--;demoState.LoadProgress=Math.Min(99,(12-demoLoadTicks)*8);demoState.LoadStage=demoLoadTicks>=10?2:demoLoadTicks>=9?3:demoLoadTicks>=8?4:demoLoadTicks==1?7:5;demoState.LoadFile=demoState.LoadStage==5?Math.Min(4,1+(8-demoLoadTicks)/2):0;if(demoLoadTicks==0){demoState.LoadFlags=0;demoState.LoadProgress=100;demoState.LoadStage=0;demoState.LoadFile=0;demoSlot=-1;}}}
   if(demoSaveTicks>0&&--demoSaveTicks==0)demoState.ConfigFlags=10;
  }
  void ExperienceSmokeTick(DateTime now){if(experienceStart==DateTime.MinValue){experienceStart=now;actionTabs.SelectedIndex=3;demoState.LoadProgress=0;StartObservation();}double t=(now-experienceStart).TotalSeconds;
   try{
    if(t>35)throw new Exception("Experience UI stage timeout "+experienceStep);
    if(experienceStep==0&&t>.5){if(loadProgress.Value!=100)throw new Exception("Cold-boot ready progress not normalized");SendCommand("slot 1",true);experienceStep++;}
    else if(experienceStep==1&&state.Loading&&pending!=null&&pending.Accepted){if(!state.Loading||pending==null||!pending.Accepted)throw new Exception("Load accepted/completed stages collapsed");experienceStep++;}
    else if(experienceStep==2&&state.Slot==1&&!state.Loading&&pending==null){if(state.Slot!=1||state.Loading||pending!=null)throw new Exception("Slot completion missing");SendCommand("light 50",true);experienceStep++;}
    else if(experienceStep==3&&pending==null&&state.ConfigBrightness==128){SendCommand("save",true);experienceStep++;}
    else if(experienceStep==4&&pending==null&&state.SaveComplete){if(pending!=null||!state.SaveComplete)throw new Exception("Save result missing");scheduleEnabled.Checked=true;demoState.ManualCounter++;experienceStep++;}
    else if(experienceStep==5&&!scheduleEnabled.Checked){if(scheduleEnabled.Checked)throw new Exception("Physical switch did not suspend scheduling");SaveScreenshot("ui_experience.png");StopObservation();File.WriteAllText(Path.Combine(captureDir,"experience_smoke.json"),new JavaScriptSerializer().Serialize(new{passed=true,physical_port_opened=physicalPortEverOpened,receipt_then_complete=true,slot_loading=true,save_confirmed=true,manual_override=true,observation_demo_only=true}));Close();}
   }catch(Exception e){File.WriteAllText(Path.Combine(captureDir,"experience_smoke.json"),new JavaScriptSerializer().Serialize(new{passed=false,error=e.ToString()}));Environment.ExitCode=1;Close();}
  }
 }
}
