// MallGuard 商场多媒体与应急显示终端 · Windows控制台
// 职责：寻人/寻物卡片上传与回传确认；上传被应急打断时停止并提示重发。
// 保留V5.1类/方法标识以兼容现有测试，文件名按产品职责组织。
using System;
using System.Drawing;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;
namespace MallDisplayConsole {
 public sealed partial class MainForm {
  TabControl actionTabs;RadioButton findPeople,findObject;TextBox findName;Button publishFinder,closeFinder;Label finderFeedback,finderStatus;ProgressBar finderProgress;PictureBox finderPreview;
  volatile bool finderCancel;bool finderBusy;int finderEpoch;FinderPayload published;
  DateTime previewDue=DateTime.MaxValue,noticeSent;int pendingNotice=-1,pendingNoticeId;int? noticePreviousSequence;
  public static bool FinderSmokeEnabled;int finderSmokeStep;DateTime finderSmokeTime;
  Control BuildActionTabs(){TabControl tabs=new TabControl{Dock=DockStyle.Fill};actionTabs=tabs;TabPage a=new TabPage("应急控制"),b=new TabPage("寻人 / 寻物广播");a.Controls.Add(BuildEmergencies());b.Controls.Add(BuildFinder());TabPage c=new TabPage("播放 / 参数");c.Controls.Add(BuildPlayback());TabPage experience=new TabPage("时段 / 素材 / 验收");experience.Controls.Add(BuildExperience());TabPage guidedPage=new TabPage("一键引导演示");guidedPage.Controls.Add(BuildGuided());tabs.TabPages.AddRange(new[]{c,a,b,experience,guidedPage});if(smoke)tabs.SelectedTab=a;return tabs;}
  Control BuildFinder(){
   Panel panel=new Panel{Dock=DockStyle.Fill,Padding=new Padding(0,4,0,6)};
   Card right=new Card{Dock=DockStyle.Right,Width=226,Padding=new Padding(8)};Label title=Theme.Label("通知卡片预览",9,Theme.Navy,true);title.Dock=DockStyle.Top;title.Height=24;Label caption=Theme.Label("右侧弹窗约占画面40%\n广告继续播放，应急优先",8,Theme.Muted);caption.Dock=DockStyle.Bottom;caption.Height=34;finderPreview=new PictureBox{Dock=DockStyle.Fill,SizeMode=PictureBoxSizeMode.Zoom,BackColor=Theme.Page};right.Controls.Add(finderPreview);right.Controls.Add(caption);right.Controls.Add(title);
   Card left=new Card{Dock=DockStyle.Fill,Padding=new Padding(12,8,12,8)};
   FlowLayoutPanel types=new FlowLayoutPanel{Dock=DockStyle.Top,Height=28};findPeople=new RadioButton{Text="寻人广播",Checked=true,AutoSize=true};findObject=new RadioButton{Text="寻物广播",AutoSize=true,Margin=new Padding(20,3,0,0)};types.Controls.AddRange(new Control[]{findPeople,findObject});
   Panel nameRow=new Panel{Dock=DockStyle.Top,Height=34};Label n=Theme.Label("姓名 / 物品",9,Theme.Muted);n.Dock=DockStyle.Left;n.Width=86;findName=new TextBox{Dock=DockStyle.Fill,Text="何一凡",MaxLength=32,Font=Theme.Text(11)};nameRow.Controls.Add(findName);nameRow.Controls.Add(n);
   FlowLayoutPanel actions=new FlowLayoutPanel{Dock=DockStyle.Top,Height=40,Padding=new Padding(0,3,0,0)};publishFinder=Button("发布广播",Theme.Blue,true);publishFinder.Width=140;closeFinder=Button("已找到 / 关闭通知",Theme.Blue,false);closeFinder.Width=166;actions.Controls.AddRange(new Control[]{publishFinder,closeFinder});
   finderProgress=new ProgressBar{Dock=DockStyle.Top,Height=8,Minimum=0,Maximum=304};finderFeedback=Theme.Label("输入1～16个字；中文名称自动生成清晰字模后下发。",8.5f,Theme.Muted);finderFeedback.Dock=DockStyle.Top;finderFeedback.Height=44;
   finderStatus=Theme.Label("等待 v21 状态回传",8.5f,Theme.Muted);finderStatus.Dock=DockStyle.Bottom;finderStatus.Height=30;
   left.Controls.Add(finderFeedback);left.Controls.Add(finderProgress);left.Controls.Add(actions);left.Controls.Add(nameRow);left.Controls.Add(types);left.Controls.Add(finderStatus);
   publishFinder.Click+=delegate{PublishFinder();};closeFinder.Click+=delegate{SendCommand("found",true);};
   EventHandler changed=delegate{previewDue=DateTime.UtcNow.AddMilliseconds(250);};findName.TextChanged+=changed;findPeople.CheckedChanged+=changed;findObject.CheckedChanged+=changed;previewDue=DateTime.UtcNow;
   panel.Controls.Add(left);panel.Controls.Add(right);return panel;
  }
  bool TryFinderCommand(string text){Match m=Regex.Match(text,"^find +(?<kind>people|object) +[\"“](?<name>.+)[\"”]$",RegexOptions.IgnoreCase);if(!m.Success)return false;findObject.Checked=m.Groups["kind"].Value.Equals("object",StringComparison.OrdinalIgnoreCase);findPeople.Checked=!findObject.Checked;findName.Text=m.Groups["name"].Value;PublishFinder();return true;}
  void SafeUi(Action action){if(closing||IsDisposed)return;try{BeginInvoke((Action)delegate{if(!closing)action();});}catch(InvalidOperationException){}}
  void CancelFinderUpload(){finderCancel=true;finderEpoch++;finderBusy=false;pendingNotice=-1;}
  void BeginNoticeConfirmation(int kind,int id,DateTime sent){pendingNotice=kind;pendingNoticeId=id;noticeSent=sent;noticePreviousSequence=state==null?(int?)null:state.Sequence;finderFeedback.Text="指令已发送，等待板端确认通知状态。";}
  void PublishFinder(){
   if(guided.Running&&!guidedDispatch)StopGuided("用户手动发布广播");
   if(finderBusy)return;
   if(!Fresh||state.Version<21){finderFeedback.Text="请连接配套v21固件并等待实时状态；也可使用离线演示。";return;}
   if(state.Emergency!=0){finderFeedback.Text="当前应急优先，请在应急结束后发布新通知。";return;}
   if(!state.BootReady){finderFeedback.Text="开发板尚未加载完成，请稍后发布。";return;}
   FinderPayload payload;try{int id=(Environment.TickCount^DateTime.UtcNow.Millisecond)&65535;if(state.NoticeId==id)id=(id+1)&65535;payload=FinderPayload.Create(findPeople.Checked?1:2,findName.Text,id);}catch(Exception e){finderFeedback.Text=e.Message;return;}
   published=payload;finderBusy=true;finderCancel=false;finderProgress.Value=0;finderFeedback.Text="正在上传中文卡片，约3秒，广告继续播放…";
   bool simulated=demo;SerialLink sender=link;int epoch=++finderEpoch,portEpoch=session;long sentBytes=0;
   ThreadPool.QueueUserWorkItem(delegate{
    try{
     Action<string> send=delegate(string s){if(finderCancel||epoch!=finderEpoch||portEpoch!=session)throw new OperationCanceledException();byte[] bytes=Encoding.UTF8.GetBytes(s);if(!simulated)sender.Send(bytes);sentBytes+=bytes.Length;};
     send(payload.Header);Thread.Sleep(100); // Wait for a whole old display frame to hide before RAM writes.
     for(int y=0;y<304;y++){send(payload.Row(y));if(y%16==0){int done=y+1;SafeUi(delegate{if(epoch==finderEpoch)finderProgress.Value=done;});}if(simulated)Thread.Sleep(0);}
     if(finderCancel||epoch!=finderEpoch||portEpoch!=session)throw new OperationCanceledException();
     if(!simulated&&state!=null&&state.Emergency!=0)throw new InvalidOperationException("上传期间进入应急；字模已暂存，应急结束后请重新发布。");
     send(payload.Command);DateTime sent=DateTime.UtcNow;
     SafeUi(delegate{
      if(epoch!=finderEpoch)return;finderBusy=false;finderProgress.Value=304;txBytes+=sentBytes;
      AddLog("TX",payload.Command.Trim()+"（含15200字节字模，CRC="+payload.MaskCrc.ToString("X4")+"，ID="+payload.Id.ToString("X4")+"）",Encoding.UTF8.GetBytes(payload.Command));
      BeginNoticeConfirmation(payload.Kind,payload.Id,sent);
      if(simulated){demoState.NoticeKind=payload.Kind;demoState.NoticeId=payload.Id;demoState.NoticeFlags=13;demoState.NoticeError=0;}
     });
    }catch(OperationCanceledException){SafeUi(delegate{if(epoch==finderEpoch){finderBusy=false;finderFeedback.Text="发布已取消。";}});}
    catch(Exception e){SafeUi(delegate{if(epoch==finderEpoch){finderBusy=false;finderFeedback.Text="发布未完成："+e.Message;AddLog("WARN",finderFeedback.Text,null);StopGuided(finderFeedback.Text);}});}
   });
  }
  void ConfirmFinder(BoardState s){if(s.Version<21||pendingNotice<0)return;if(s.ReceivedUtc<noticeSent||noticePreviousSequence.HasValue&&s.Sequence==noticePreviousSequence.Value)return;
   if(s.NoticeError!=0){finderFeedback.Text="通知被拒绝或加载失败：N"+s.NoticeError.ToString("X1");GuidedResult(pendingNotice==0?"found":pendingNotice==1?"@people":"@object",false,finderFeedback.Text);pendingNotice=-1;return;}
   if(s.NoticeKind==pendingNotice&&(pendingNotice==0||s.NoticeId==pendingNoticeId)&&s.NoticeError==0){finderFeedback.Text=pendingNotice==0?"板端已确认关闭通知，恢复广告音乐。":s.Emergency!=0?"通知已保存；应急结束后恢复显示与提示音。":"板端已确认发布；广告继续播放，提示音遵循当前音量。";AddEvent(finderFeedback.Text);GuidedResult(pendingNotice==0?"found":pendingNotice==1?"@people":"@object",true,finderFeedback.Text);pendingNotice=-1;}}
  void UpdateFinder(){if(publishFinder==null)return;
   publishFinder.Enabled=!guided.Running&&!finderBusy&&Fresh&&state.Version>=21&&state.Emergency==0&&state.BootReady;closeFinder.Enabled=IsConnected&&state!=null&&state.Version>=21;
   if(DateTime.UtcNow>=previewDue){previewDue=DateTime.MaxValue;try{using(Bitmap b=FinderPayload.Create(findPeople.Checked?1:2,findName.Text,0).Preview()){if(finderPreview.Image!=null)finderPreview.Image.Dispose();finderPreview.Image=new Bitmap(b);}}catch{if(finderPreview.Image!=null){finderPreview.Image.Dispose();finderPreview.Image=null;}}}
   if(pendingNotice>=0&&(DateTime.UtcNow-noticeSent).TotalSeconds>5){finderFeedback.Text="未收到通知状态确认；请检查连接及板端通知错误码。";GuidedResult(pendingNotice==0?"found":pendingNotice==1?"@people":"@object",false,finderFeedback.Text);pendingNotice=-1;}
   if(state==null||state.Version<21){finderStatus.Text="寻人/寻物功能需要配套 v21 固件。";return;}
   string name=published!=null&&published.Id==state.NoticeId?published.Name:"外部终端下发";
   finderStatus.Text=(Fresh?"板端：":"历史：")+(state.NoticeKind==0?"无广播":(state.NoticeKind==1?"寻人 · ":"寻物 · ")+name+(state.Emergency!=0?"（应急挂起）":""))+"  · 提示音素材"+((state.NoticeFlags&4)!=0?"存在":"缺失")+"  · N"+state.NoticeError.ToString("X1");
  }
  void StartFinderSmoke(){finderSmokeTime=DateTime.UtcNow;}
  void FinderSmokeTick(DateTime now){double t=(now-finderSmokeTime).TotalSeconds;
   try{
    if(finderSmokeStep==0&&t>1){if(!Fresh||state.Version<21)throw new Exception("no v21+ demo");actionTabs.SelectedIndex=2;findName.Text="何一凡";PublishFinder();finderSmokeStep++;}
    else if(finderSmokeStep==1&&t>3.5){if(state.NoticeKind!=1||pendingNotice!=-1||finderBusy)throw new Exception("people publish not confirmed");published.Preview().Save(Path.Combine(captureDir,"finder_people.png"));SaveScreenshot("ui_finder.png");SendCommand("fire",true);finderSmokeStep++;}
    else if(finderSmokeStep==2&&t>4.2){if(state.Emergency!=1||state.NoticeKind!=1)throw new Exception("emergency did not preserve notice");SendCommand("put_out",true);finderSmokeStep++;}
    else if(finderSmokeStep==3&&t>5){if(state.Emergency!=0||state.NoticeKind!=1)throw new Exception("notice not resumed");SendCommand("found",true);finderSmokeStep++;}
    else if(finderSmokeStep==4&&t>5.7){if(state.NoticeKind!=0||pendingNotice!=-1)throw new Exception("found not confirmed");findObject.Checked=true;findName.Text="蓝色双肩包";PublishFinder();finderSmokeStep++;}
    else if(finderSmokeStep==5&&t>8){if(state.NoticeKind!=2||finderBusy||pendingNotice!=-1)throw new Exception("object publish not confirmed");published.Preview().Save(Path.Combine(captureDir,"finder_object.png"));SendCommand("found",true);finderSmokeStep++;}
    else if(finderSmokeStep==6&&t>8.8){if(state.NoticeKind!=0||physicalPortEverOpened)throw new Exception("close/isolation");File.WriteAllText(Path.Combine(captureDir,"finder_smoke.json"),new JavaScriptSerializer().Serialize(new{passed=true,physical_port_opened=false,people=true,objects=true,found=true,emergency_preserved=true}),Encoding.UTF8);Close();}
   }catch(Exception e){Directory.CreateDirectory(captureDir);File.WriteAllText(Path.Combine(captureDir,"finder_smoke.json"),new JavaScriptSerializer().Serialize(new{passed=false,error=e.Message}),Encoding.UTF8);Environment.ExitCode=1;Close();}
  }
 }
}
