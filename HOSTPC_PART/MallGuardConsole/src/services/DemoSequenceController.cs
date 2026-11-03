// MallGuard 商场多媒体与应急显示终端 · Windows控制台
// 职责：演示步骤状态机，记录期望状态并检测外部接管；不盲目重发。
// 保留V5.1类/方法标识以兼容现有测试，文件名按产品职责组织。
using System;
using System.Collections.Generic;

namespace MallDisplayConsole {
 public sealed class GuidedStep {
  public string Command,Caption;public double TimeoutSeconds;
  public GuidedStep(string command,string caption,double timeout){Command=command;Caption=caption;TimeoutSeconds=timeout;}
 }
 // This model never writes to a transport. Every step must be dispatched once and
 // explicitly confirmed by the form's receipt/target matcher before it advances.
 public sealed class GuidedSequence {
  readonly List<GuidedStep> steps=new List<GuidedStep>();
  public bool Running {get;private set;}public bool Awaiting {get;private set;}public bool Completed {get;private set;}
  public bool Offline {get;private set;}public int Index {get;private set;}public int Count {get{return steps.Count;}}
  public string Status {get;private set;}public DateTime Deadline {get;private set;}
  public BoardState Baseline {get;private set;}public double DwellSeconds=1.25;
  int expectedEmergency,expectedNotice,expectedSlot;bool expectedVideoMode,expectedPaused;DateTime readyAt;public GuidedStep Current {get{return Index<steps.Count?steps[Index]:null;}}
  void Add(string c,string caption,double timeout){steps.Add(new GuidedStep(c,caption,timeout));}
  public bool Start(BoardState baseline,bool offline,DateTime now,out string reason){
   reason=null;if(Running){reason="演示已在运行";return false;}
   if(baseline==null||baseline.Version<25||!baseline.BootReady||baseline.Loading||baseline.LoadFailed||baseline.ConfigBusy||baseline.CachedFrame||baseline.Emergency!=0||baseline.NoticeKind!=0||baseline.NoticeError!=0||baseline.Error!=0||baseline.VideoError!=0||baseline.HasLoadDetail&&baseline.LoadError!=0||!baseline.VideoLoaded||baseline.ReadyMask!=15){reason="需要S25及以上实时状态、素材就绪、无错误且无应急/广播/加载；四张应急图与视频须就绪";return false;}
   Baseline=baseline.Copy();Offline=offline;steps.Clear();Index=0;Completed=false;Awaiting=false;expectedEmergency=expectedNotice=0;expectedSlot=baseline.Slot;expectedVideoMode=baseline.VideoMode;expectedPaused=(baseline.VideoFlags&2)!=0;readyAt=now;
   Add("ads","进入广告界面",3);
   for(int i=1;i<=4;i++){int slot=(baseline.Slot+i)%4;Add("slot "+slot,"展示"+new[]{"默认","早间","午间","晚间"}[slot]+"四图素材组",45);}
   Add("video","播放视频",3);Add("pause","暂停视频",3);Add("play","继续视频",3);Add("ads","返回广告",3);
   Add("@people","发布寻人：何一凡",12);Add("found","确认已找到并关闭寻人",5);
   Add("@object","发布寻物：蓝色双肩包",12);Add("found","确认已找到并关闭寻物",5);
   for(int i=1;i<=4;i++){Add(Protocol.Starts[i],"演示触发："+Protocol.Names[i],3);Add(Protocol.Ends[i],"演示解除并恢复："+Protocol.Names[i],3);}
   if(baseline.VideoMode){Add("video","恢复开始时的视频界面",3);if(!baseline.VideoPlaying)Add("pause","恢复开始时的暂停状态",3);}
   Running=true;Status=(offline?"离线模拟":"实物串口")+"演示已启动；逐步等待回执与目标状态";return true;
  }
  public GuidedStep TakeNext(DateTime now){if(!Running||Awaiting||now<readyAt)return null;if(Index>=steps.Count){Running=false;Completed=true;Status=(Offline?"离线模拟":"实物串口")+"演示完成，四时段/视频/寻人寻物/四类应急及恢复均经状态确认";return null;}Awaiting=true;Deadline=now.AddSeconds(Current.TimeoutSeconds);Status="等待确认 "+(Index+1)+" / "+Count+"："+Current.Caption;return Current;}
  public bool Confirm(string command,DateTime now){if(!Running||!Awaiting||Current==null||Current.Command!=command)return false;if(now>=Deadline){Stop("确认已超过步骤时限；不自动重发");return false;}int target;bool ending;if(Protocol.CommandTarget(command,out target,out ending))expectedEmergency=target;if(command=="@people")expectedNotice=1;if(command=="@object")expectedNotice=2;if(command=="found")expectedNotice=0;if(command=="video"){expectedVideoMode=true;expectedPaused=false;}if(command=="ads")expectedVideoMode=false;if(command=="pause")expectedPaused=true;if(command=="play")expectedPaused=false;if(command.StartsWith("slot ",StringComparison.Ordinal))expectedSlot=Int32.Parse(command.Substring(5));Awaiting=false;Index++;readyAt=now.AddSeconds(DwellSeconds);Status="已确认 "+Index+" / "+Count+"；展示后继续";return true;}
  public bool SceneMatches(BoardState s){
   if(s==null)return false;int emergency=expectedEmergency,notice=expectedNotice,slot=expectedSlot,target;bool ending,video=expectedVideoMode,paused=expectedPaused;
   if(Awaiting&&Current!=null){string command=Current.Command;
    if(Protocol.CommandTarget(command,out target,out ending)&&(s.Emergency==target||s.Emergency==expectedEmergency))emergency=s.Emergency;
    if(command=="@people"&&(s.NoticeKind==0||s.NoticeKind==1))notice=s.NoticeKind;
    if(command=="@object"&&(s.NoticeKind==0||s.NoticeKind==2))notice=s.NoticeKind;
    if(command=="found"&&(s.NoticeKind==0||s.NoticeKind==expectedNotice))notice=s.NoticeKind;
    if(command.StartsWith("slot ",StringComparison.Ordinal)&&(s.Slot==expectedSlot||s.Slot==Int32.Parse(command.Substring(5))))slot=s.Slot;
    if(command=="video"&&(s.VideoMode==expectedVideoMode||s.VideoMode))video=s.VideoMode;
    if(command=="ads"&&(s.VideoMode==expectedVideoMode||!s.VideoMode))video=s.VideoMode;
    if(command=="pause"||command=="play"||command=="video"||command=="ads")paused=(s.VideoFlags&2)!=0;
   }
   return s.Emergency==emergency&&s.NoticeKind==notice&&s.Slot==slot&&s.VideoMode==video&&(!video||((s.VideoFlags&2)!=0)==paused);
  }
  public void Stop(string reason){if(!Running)return;Running=false;Awaiting=false;Completed=false;Status="演示已停止："+reason+"。停止后不再发送；当前板端状态保留，应急须人工核实后明确解除。已排队操作仍可能执行。";}
  public void Tick(DateTime now,bool connected,bool fresh){if(!Running)return;if(!connected){Stop("连接已断开");return;}if(!fresh){Stop("回传超过2秒");return;}if(Awaiting&&now>=Deadline)Stop("步骤超时，执行结果未确认；不自动重发");}
 }
}
