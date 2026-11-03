// MallGuard 商场多媒体与应急显示终端 · Windows控制台
// 职责：引导演示界面；等待板端确认，遇拒绝、超时、断线或手动接管停止。
// 保留V5.1类/方法标识以兼容现有测试，文件名按产品职责组织。
using System;
using System.Drawing;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;
namespace MallDisplayConsole {
 public sealed partial class MainForm {
  public static bool GuidedSmokeEnabled;
  string guidedAttemptError="";readonly GuidedSequence guided=new GuidedSequence();bool guidedDispatch,guidedStopLogged,guidedOfflineArmed;Label guidedStatus,guidedMode,guidedLoad;Button guidedStart,guidedOffline,guidedStop;ProgressBar guidedProgress;
  int guidedSmokeStage;DateTime guidedSmokeStart;long guidedStopBytes;bool guidedCompleteSeen,guidedCancelSeen,guidedRejectSeen,guidedTimeoutSeen,guidedLoadCaptureSeen,guidedSw4Seen,guidedSlotOverrideSeen;
  Control BuildGuided(){
   Panel p=new Panel{Dock=DockStyle.Fill,Padding=new Padding(12,6,12,4),BackColor=Color.White};
   guidedMode=Theme.Label("离线模拟与实物演示分开启动；实物操作会真实触发应急、广播和视频。",9,Theme.Navy,true);guidedMode.Dock=DockStyle.Top;guidedMode.Height=30;
   FlowLayoutPanel buttons=new FlowLayoutPanel{Dock=DockStyle.Top,Height=40,WrapContents=false};
   guidedOffline=Button("一键离线演示",Theme.Blue,true);guidedOffline.Width=145;guidedOffline.Height=30;guidedOffline.Click+=delegate{if(IsConnected&&!demo)return;if(!demo){StartDemo();guidedOfflineArmed=true;guidedStatus.Text="离线模拟已启动，等待首个模拟状态后自动开始流程。";}else StartGuided();};
   guidedStart=Button("开始实物引导演示",Theme.Blue,false);guidedStart.Width=170;guidedStart.Height=30;guidedStart.Click+=delegate{StartGuided();};
   guidedStop=Button("停止流程 · 保留板端状态",Color.FromArgb(181,65,53),false);guidedStop.Width=205;guidedStop.Height=30;guidedStop.Click+=delegate{StopGuided("用户点击停止");};buttons.Controls.AddRange(new Control[]{guidedOffline,guidedStart,guidedStop});
   guidedProgress=new ProgressBar{Dock=DockStyle.Top,Height=10};guidedStatus=Theme.Label("待启动：四时段 → 视频暂停/继续 → 寻人/寻物 → 四类应急触发/解除 → 恢复初始时段和视频模式。",9,Theme.Navy);guidedStatus.Dock=DockStyle.Top;guidedStatus.Height=48;
   Label safety=Theme.Label("每步只发送一次，等待回执与后续状态；拒绝、加载失败、超时、断线或手动接管即停止。停止/断开/退出不会发送结束应急或found。当前真实告警须人工核实后在应急页明确解除。",8.5f,Theme.Muted);safety.Dock=DockStyle.Top;safety.Height=43;
   guidedLoad=Theme.Label("加载详情等待回传",8.5f,Theme.Muted);guidedLoad.Dock=DockStyle.Top;guidedLoad.Height=38;
   p.Controls.Add(guidedLoad);p.Controls.Add(safety);p.Controls.Add(guidedStatus);p.Controls.Add(guidedProgress);p.Controls.Add(buttons);p.Controls.Add(guidedMode);return p;
  }
  void StartGuided(){
   if(!Fresh||finderBusy||pending!=null||pendingNotice>=0){guidedAttemptError="等待实时状态及当前操作结束后再启动。";guidedStatus.Text=guidedAttemptError;return;}
   string reason;if(!guided.Start(state,demo,DateTime.UtcNow,out reason)){guidedAttemptError="无法开始："+reason;guidedStatus.Text=guidedAttemptError;return;}
   guidedAttemptError="";if(scheduleEnabled.Checked)scheduleEnabled.Checked=false;guidedStopLogged=false;TrackCommand("引导演示","启动",demo?"离线模拟，不打开物理串口":"用户明确点击；将真实触发应急并逐步解除");AddLog("INFO",guided.Status,null);
  }
  void StopGuided(string reason){
   guidedOfflineArmed=false;if(!guided.Running)return;guided.Stop(reason);guidedStatus.Text=guided.Status;guidedStatus.ForeColor=Color.FromArgb(181,65,53);guidedStop.Enabled=false;CancelFinderUpload();if(scheduleEnabled.Checked)scheduleEnabled.Checked=false;LogGuidedStop();
  }
  void LogGuidedStop(){if(guidedStopLogged)return;guidedStopLogged=true;CancelFinderUpload();if(scheduleEnabled.Checked)scheduleEnabled.Checked=false;TrackCommand("引导演示",guided.Completed?"完成":"停止",guided.Status);AddLog(guided.Completed?"INFO":"WARN",guided.Status,null);AddEvent(guided.Status);}
  void GuidedResult(string command,bool success,string detail){if(!guided.Running||!guided.Awaiting||guided.Current==null||guided.Current.Command!=command)return;if(success){guided.Confirm(command,DateTime.UtcNow);if(!guided.Running)LogGuidedStop();}else StopGuided(detail);}
  void UpdateGuided(DateTime now){
   if(guidedStatus==null)return;if(guidedOfflineArmed&&demo&&Fresh){guidedOfflineArmed=false;StartGuided();}bool wasRunning=guided.Running;guided.Tick(now,IsConnected,Fresh);
   if(wasRunning&&!guided.Running)LogGuidedStop();
   if(guided.Running&&state!=null){
    if(pending!=null&&pending.SlotRestartObserved&&!state.BootReady)return;
    if(state.Version!=guided.Baseline.Version||state.ManualCounter!=guided.Baseline.ManualCounter)StopGuided("协议变化或SW2/SW3手动接管");
    else if(!guided.SceneMatches(state))StopGuided("时段、视频/暂停、应急或广播状态被外部操作改变");
    else if(state.NoticeError!=0)StopGuided("广播错误：N"+state.NoticeError.ToString("X1"));
    else if(state.LoadFailed||state.Error!=0||state.VideoError!=0||state.HasLoadDetail&&state.LoadError!=0)StopGuided("设备报告错误："+Protocol.LoadDetail(state)+" / VE"+state.VideoError.ToString("X2"));
    else if(state.ConfigVolume!=guided.Baseline.ConfigVolume||state.ConfigBrightness!=guided.Baseline.ConfigBrightness||state.PeriodMs!=guided.Baseline.PeriodMs||state.Auto!=guided.Baseline.Auto)StopGuided("播放参数被外部修改");
   }
   if(guided.Running){GuidedStep next=guided.TakeNext(now);if(next!=null){
    TrackCommand(next.Command,"引导步骤",next.Caption);guidedDispatch=true;
    try{if(next.Command=="@people"||next.Command=="@object"){findPeople.Checked=next.Command=="@people";findObject.Checked=!findPeople.Checked;findName.Text=findPeople.Checked?"何一凡":"蓝色双肩包";PublishFinder();}else {SendCommand(next.Command,true);if(next.Command=="video"&&pending!=null)pending.Expected=s=>s.Version>=25&&s.VideoMode&&s.VideoLoaded&&s.VideoPlaying&&!s.VideoBuffering&&s.VideoError==0;}}
    finally{guidedDispatch=false;}
    if(pending==null&&pendingNotice<0&&!finderBusy)StopGuided("步骤未能发送："+next.Caption);
   }if(!guided.Running)LogGuidedStop();}
   scheduleEnabled.Enabled=!guided.Running;guidedOffline.Enabled=!guided.Running&&(!IsConnected||demo);guidedStart.Enabled=!guided.Running&&Fresh;guidedStart.Text=demo?"开始当前离线流程":"开始实物引导演示";guidedStop.Enabled=guided.Running||guidedOfflineArmed;
   guidedMode.Text=demo?"离线模拟 · 不连接硬件；模拟数据不能作为实物验收结果":IsConnected?"实物串口 · 点击开始会真实触发四类应急；请先确认现场允许演示":"未连接 · 一键离线演示可先熟悉流程";
   guidedProgress.Maximum=Math.Max(1,guided.Count);guidedProgress.Value=Math.Min(guided.Index,guidedProgress.Maximum);if(!String.IsNullOrEmpty(guidedAttemptError))guidedStatus.Text=guidedAttemptError;else if(!String.IsNullOrEmpty(guided.Status))guidedStatus.Text=guided.Status;
   guidedStatus.ForeColor=guided.Completed?Color.FromArgb(20,132,104):!guided.Running&&guided.Count>0?Color.FromArgb(181,65,53):Theme.Navy;
   guidedLoad.Text=(Fresh?"":"[无实时回传] ")+Protocol.LoadDetail(state);
  }
  void GuidedSmokeTick(DateTime now){
   try{
    if(guidedSmokeStart==DateTime.MinValue){guidedSmokeStart=now;actionTabs.SelectedIndex=4;guided.DwellSeconds=.05;}
    if((now-guidedSmokeStart).TotalSeconds>90)throw new Exception("Guided UI timeout stage "+guidedSmokeStage+" / "+guided.Status);
    if(!guidedLoadCaptureSeen&&state!=null&&state.Loading&&state.LoadFile>0){SaveScreenshot("ui_loading_detail.png");guidedLoadCaptureSeen=true;}
    if(guidedSmokeStage==0&&Fresh){Disconnect();guidedOffline.PerformClick();if(!demo||!guidedOfflineArmed)throw new Exception("One-click offline startup failed");guidedSmokeStage++;}
    else if(guidedSmokeStage==1&&guided.Completed){if(!guidedCompleteSeen){guidedCompleteSeen=true;guidedSmokeStart=now;return;}if((now-guidedSmokeStart).TotalSeconds<.6)return;if(state.Emergency!=0||state.NoticeKind!=0||state.Slot!=0||state.VideoMode||state.ConfigVolume!=128||state.ConfigBrightness!=192)throw new Exception("Guided restoration missing");SaveScreenshot("ui_guided_complete.png");guidedStart.PerformClick();guidedSmokeStage++;}
    else if(guidedSmokeStage==2&&guided.Running&&state.Emergency==1&&pending==null){guidedStop.PerformClick();guidedStopBytes=txBytes;if(guided.Running||state.Emergency!=1)throw new Exception("Cancellation ended emergency");SaveScreenshot("ui_guided_stopped.png");guidedSmokeStart=now;guidedSmokeStage++;}
    else if(guidedSmokeStage==3&&(now-guidedSmokeStart).TotalSeconds>.6){if(txBytes!=guidedStopBytes||state.Emergency!=1)throw new Exception("Cancelled sequence transmitted");guidedCancelSeen=true;SendCommand("put_out",true);guidedSmokeStage++;}
    else if(guidedSmokeStage==4&&state.Emergency==0&&pending==null){guidedStart.PerformClick();if(!guided.Running)throw new Exception("Restart failed");guidedSmokeStage++;}
    else if(guidedSmokeStage==5&&pending!=null){demoState.ReceiptStatus=2;guidedSmokeStage++;}
    else if(guidedSmokeStage==6&&!guided.Running&&pending==null){if(!guided.Status.Contains("停止"))throw new Exception("Rejected command did not stop");guidedRejectSeen=true;guidedStart.PerformClick();guidedSmokeStage++;}
    else if(guidedSmokeStage==7&&pending!=null){lastDemo=now.AddHours(1);guidedSmokeStage++;}
    else if(guidedSmokeStage==8&&!guided.Running){if(!guided.Status.Contains("超过2秒"))throw new Exception("Stale telemetry did not stop");guidedTimeoutSeen=true;guidedStopBytes=txBytes;guidedSmokeStart=now;SaveScreenshot("ui_guided_timeout.png");guidedSmokeStage++;}
    else if(guidedSmokeStage==9&&(now-guidedSmokeStart).TotalSeconds>.6){if(txBytes!=guidedStopBytes||physicalPortEverOpened)throw new Exception("Timeout retransmitted or opened physical UART");demoState.LoadFlags=6;demoState.LoadStage=9;demoState.LoadFile=3;demoState.LoadError=5;demoState.LoadElapsedSeconds=27;demoState.Error=0x22;lastDemo=DateTime.MinValue;guidedSmokeStage++;}
    else if(guidedSmokeStage==10&&Fresh&&state.LoadFailed){if(!guidedLoad.Text.Contains("LE05")||!guidedLoad.Text.Contains("CRC16")||!guidedLoad.Text.Contains("27秒"))throw new Exception("Detailed failure not visible");SaveScreenshot("ui_loading_failure.png");StartDemo();guided.DwellSeconds=3;guidedSmokeStage++;}
    else if(guidedSmokeStage==11&&Fresh){guidedStart.PerformClick();if(!guided.Running)throw new Exception("SW4 override setup failed");guidedSmokeStage++;}
    else if(guidedSmokeStage==12&&guided.Index==1&&!guided.Awaiting){demoState.VideoFlags=13;guidedSmokeStage++;}
    else if(guidedSmokeStage==13&&!guided.Running){if(!guided.Status.Contains("外部")||state.Emergency!=0)throw new Exception("SW4 during dwell was not stopped");guidedStopBytes=txBytes;guidedSmokeStart=now;SaveScreenshot("ui_guided_manual_override.png");guidedSmokeStage++;}
    else if(guidedSmokeStage==14&&(now-guidedSmokeStart).TotalSeconds>.6){if(txBytes!=guidedStopBytes||state.Emergency!=0)throw new Exception("SW4 override dispatched another step");guidedSw4Seen=true;StartDemo();guidedSmokeStage++;}
    else if(guidedSmokeStage==15&&Fresh){guidedStart.PerformClick();if(!guided.Running)throw new Exception("External slot override setup failed");guidedSmokeStage++;}
    else if(guidedSmokeStage==16&&guided.Index==1&&!guided.Awaiting){demoState.Slot=(demoState.Slot+1)%4;guidedSmokeStage++;}
    else if(guidedSmokeStage==17&&!guided.Running){if(!guided.Status.Contains("外部")||state.Emergency!=0)throw new Exception("External slot during dwell was not stopped");guidedStopBytes=txBytes;guidedSmokeStart=now;guidedSmokeStage++;}
    else if(guidedSmokeStage==18&&(now-guidedSmokeStart).TotalSeconds>.6){if(txBytes!=guidedStopBytes||state.Emergency!=0)throw new Exception("Slot override dispatched another step");guidedSlotOverrideSeen=true;File.WriteAllText(Path.Combine(captureDir,"guided_smoke.json"),new JavaScriptSerializer().Serialize(new{passed=true,physical_port_opened=physicalPortEverOpened,offline_full_sequence=guidedCompleteSeen,cancel_preserved_emergency=guidedCancelSeen,rejection_stopped=guidedRejectSeen,stale_timeout_stopped=guidedTimeoutSeen,no_blind_resend=true,load_detail_visible=guidedLoadCaptureSeen,load_failure_visible=true,sw4_dwell_override_stopped=guidedSw4Seen,external_slot_dwell_override_stopped=guidedSlotOverrideSeen,one_click_from_disconnected=true,protocol=state.Version}),Encoding.UTF8);Close();}
   }catch(Exception e){Directory.CreateDirectory(captureDir);File.WriteAllText(Path.Combine(captureDir,"guided_smoke.json"),new JavaScriptSerializer().Serialize(new{passed=false,error=e.ToString()}),Encoding.UTF8);Environment.ExitCode=1;Close();}
  }
 }
}
