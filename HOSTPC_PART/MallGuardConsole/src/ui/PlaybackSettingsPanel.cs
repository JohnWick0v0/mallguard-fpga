// MallGuard 商场多媒体与应急显示终端 · Windows控制台
// 职责：广告/视频及音量、亮度、间隔的控制入口。
// 保留V5.1类/方法标识以兼容现有测试，文件名按产品职责组织。
using System;
using System.Drawing;
using System.Globalization;
using System.Windows.Forms;
namespace MallDisplayConsole {
 public sealed partial class MainForm {
  public static bool PlaybackSmokeEnabled;int playbackSmokeStep;DateTime playbackSmokeStart;
  Label playbackStatus,playbackHelp;ProgressBar videoProgress;ComboBox volumeChoice,lightChoice,periodChoice;
  FlowLayoutPanel playbackActions,parameterActions;Button pauseVideo;
  Control BuildPlayback(){
   Card panel=new Card{Dock=DockStyle.Fill,Padding=new Padding(12,8,12,8),AutoScroll=true};
   playbackStatus=Theme.Label("连接设备后显示真实播放状态",11,Theme.Navy,true);playbackStatus.Dock=DockStyle.Top;playbackStatus.Height=28;
   videoProgress=new ProgressBar{Dock=DockStyle.Top,Height=10,Maximum=159};
   playbackActions=new FlowLayoutPanel{Dock=DockStyle.Top,Height=42,WrapContents=false,AutoScroll=true};
   AddPlaybackButton(playbackActions,"广告界面","ads");AddPlaybackButton(playbackActions,"视频界面","video");pauseVideo=AddPlaybackButton(playbackActions,"暂停视频","pause");AddPlaybackButton(playbackActions,"继续视频","play");AddPlaybackButton(playbackActions,"上一张","prev");AddPlaybackButton(playbackActions,"下一张","next");AddPlaybackButton(playbackActions,"自动 A","auto");AddPlaybackButton(playbackActions,"手动 E","manual");
   parameterActions=new FlowLayoutPanel{Dock=DockStyle.Top,Height=42,WrapContents=false,AutoScroll=true};
   volumeChoice=ParameterChoice(parameterActions,"音量",new[]{"0","25","50","75","100"},"50","vol");
   lightChoice=ParameterChoice(parameterActions,"亮度",new[]{"25","50","75","100"},"100","light");
   periodChoice=ParameterChoice(parameterActions,"间隔秒",new[]{"2","5","10","30","60"},"10","interval");
   playbackHelp=Theme.Label("SW4下拨进入视频，上拨返回广告；再次拨动可覆盖上位机选择。\n应急优先，视频进度暂停；解除后继续。SW2/3投放时段在广告界面生效。\n参数仅写入当前会话；KEY1+KEY2长按2秒保存音量、亮度/对比度、间隔、A/E模式至Flash。配套V25也支持管理页保存按钮。",8.5f,Theme.Muted);playbackHelp.Dock=DockStyle.Top;playbackHelp.Height=61;
   panel.Controls.Add(playbackHelp);panel.Controls.Add(parameterActions);panel.Controls.Add(playbackActions);panel.Controls.Add(videoProgress);panel.Controls.Add(playbackStatus);return panel;
  }
  Button AddPlaybackButton(FlowLayoutPanel parent,string caption,string command){Button b=Button(caption,Theme.Blue,false);b.AutoSize=false;b.Width=90;b.Height=30;b.Margin=new Padding(0,5,6,3);b.Tag=command;b.Click+=delegate{SendCommand(command,true);};parent.Controls.Add(b);return b;}
  ComboBox ParameterChoice(FlowLayoutPanel parent,string caption,string[] values,string initial,string command){Label l=Theme.Label(caption,9,Theme.Muted);l.AutoSize=true;l.Margin=new Padding(0,11,4,3);parent.Controls.Add(l);ComboBox c=new ComboBox{DropDownStyle=ComboBoxStyle.DropDownList,Width=61,Margin=new Padding(0,7,4,3)};c.Items.AddRange(values);c.SelectedItem=initial;parent.Controls.Add(c);Button b=Button("设置",Theme.Blue,false);b.Width=54;b.Height=30;b.Margin=new Padding(0,5,16,3);b.Click+=delegate{SendCommand(command+" "+c.Text,true);};parent.Controls.Add(b);return c;}
  Func<BoardState,bool> PlaybackTarget(string text){
   string[] p=text.ToLowerInvariant().Split(' ');int n;
   switch(p[0]){
    case "video":return s=>s.Version>=23&&s.VideoMode;
    case "ads":return s=>s.Version>=23&&!s.VideoMode;
    case "pause":return s=>s.Version>=23&&(s.VideoFlags&2)!=0&&!s.VideoPlaying;
    case "play":return s=>s.Version>=23&&(s.VideoFlags&2)==0&&s.VideoPlaying;
    case "auto":return s=>s.Version>=23&&s.Auto;
    case "manual":return s=>s.Version>=23&&!s.Auto;
    case "next":{int wanted=state==null?0:state.Picture%4+1;return s=>s.Version>=23&&s.Picture==wanted;}
    case "prev":{int wanted=state==null?0:(state.Picture+2)%4+1;return s=>s.Version>=23&&s.Picture==wanted;}
    case "vol":if(p.Length==2&&Int32.TryParse(p[1],out n)&&(n==0||n==25||n==50||n==75||n==100)){int raw=n==0?0:n==25?64:n==50?128:n==75?192:255;return s=>s.Version>=23&&s.ConfigVolume==raw;}break;
    case "light":if(p.Length==2&&Int32.TryParse(p[1],out n)&&(n==25||n==50||n==75||n==100)){int raw=n>=88?255:n>=63?192:n>=38?128:64;return s=>s.Version>=23&&s.ConfigBrightness==raw;}break;
    case "interval":if(p.Length==2&&Int32.TryParse(p[1],out n)&&n>=2&&n<=60){int ms=n*1000;return s=>s.Version>=23&&s.PeriodMs==ms;}break;
    case "slot":if(p.Length==2&&Int32.TryParse(p[1],out n)&&n>=0&&n<=3){int slot=n;return s=>s.Version>=25&&s.Slot==slot&&!s.Loading&&!s.LoadFailed&&s.Emergency==0&&!s.VideoMode;}break;
    case "save":return s=>s.Version>=25&&s.SaveComplete&&!s.ConfigBusy;
   }return null;
  }
  void UpdatePlayback(){if(playbackStatus==null)return;bool capable=Fresh&&state.Version>=23;bool normal=capable&&state.Emergency==0&&!finderBusy&&pending==null&&(state.Version<25||(!state.Loading&&!state.ConfigBusy&&!state.LoadFailed));
   playbackActions.Enabled=normal;parameterActions.Enabled=normal;
   foreach(Control control in playbackActions.Controls){string cmd=control.Tag as string;
    control.Enabled=normal&&(cmd=="next"||cmd=="prev"?!state.VideoMode:cmd=="play"||cmd=="pause"?state.VideoMode&&state.VideoLoaded&&state.VideoError==0:true);
   }
   if(state==null||state.Version<23){playbackStatus.Text=state==null?"等待设备状态":"当前固件不支持视频遥控，请下载配套v23";videoProgress.Value=0;return;}
   videoProgress.Value=Math.Max(0,Math.Min(159,state.VideoFrame));
   string phase=state.VideoError!=0?"VE"+state.VideoError.ToString("X2")+" · "+Protocol.VideoErrorName(state.VideoError):!state.VideoLoaded?"等待VIDEO.BIN / 预缓冲":state.Emergency!=0?"应急优先 · 视频暂停":state.NoticeKind!=0?"广播优先 · 视频暂停":state.VideoBuffering?"补充缓冲":state.VideoPlaying?"正在播放":"已暂停";
   playbackStatus.Text=(Fresh?"":"[历史状态] ")+(state.VideoMode?"视频 · ":"广告 · ")+new[]{"默认","早间","午间","晚间"}[state.Slot]+"  |  "+(state.VideoFrame/10.0).ToString("0.0",CultureInfo.InvariantCulture)+" / 16.0 s  |  "+phase;
  }
  void DemoPlayback(string command){if(demoState==null||demoState.Emergency!=0)return;string[] p=command.Split(' ');int n;
   switch(p[0]){case "video":demoState.VideoFlags=13;break;case "ads":demoState.VideoFlags=4;break;case "pause":demoState.VideoFlags=(demoState.VideoFlags|2)&~8;break;case "play":demoState.VideoFlags=(demoState.VideoFlags|8)&~2;break;case "auto":demoState.Auto=true;break;case "manual":demoState.Auto=false;break;case "next":demoState.Picture=demoState.Picture%4+1;break;case "prev":demoState.Picture=(demoState.Picture+2)%4+1;break;}
   if(p.Length==2&&Int32.TryParse(p[1],out n)){if(p[0]=="vol")demoState.ConfigVolume=n==0?0:n==25?64:n==50?128:n==75?192:255;if(p[0]=="light")demoState.ConfigBrightness=n>=88?255:n>=63?192:n>=38?128:64;if(p[0]=="interval")demoState.PeriodMs=n*1000;}
  }
  void DemoVideoTick(){if(demoState.Version<23)return;if(demoState.VideoMode){bool running=(demoState.VideoFlags&2)==0&&demoState.Emergency==0&&demoState.NoticeKind==0;demoState.VideoFlags=running?demoState.VideoFlags|8:demoState.VideoFlags&~8;if(running)demoState.VideoFrame=(demoState.VideoFrame+2)%160;}}
  void PlaybackSmokeTick(DateTime now){if(playbackSmokeStart==DateTime.MinValue){playbackSmokeStart=now;actionTabs.SelectedIndex=0;}double t=(now-playbackSmokeStart).TotalSeconds;
   try{
    if(t>45)throw new Exception("Playback UI stage timeout "+playbackSmokeStep);
    if(playbackSmokeStep==0&&Fresh&&state.Version>=23){if(!Fresh||state.Version<23)throw new Exception("v23 demo missing");SendCommand("video",true);playbackSmokeStep++;}
    else if(playbackSmokeStep==1&&state.VideoPlaying&&state.VideoMode&&pending==null){if(!state.VideoPlaying||!state.VideoMode||pending!=null)throw new Exception("video command unconfirmed");SendCommand("pause",true);playbackSmokeStep++;}
    else if(playbackSmokeStep==2&&!state.VideoPlaying&&pending==null){if(state.VideoPlaying||pending!=null)throw new Exception("pause unconfirmed");SendCommand("vol 25",true);playbackSmokeStep++;}
    else if(playbackSmokeStep==3&&state.ConfigVolume==64&&pending==null){if(state.ConfigVolume!=64||pending!=null)throw new Exception("volume unconfirmed");SendCommand("light 50",true);playbackSmokeStep++;}
    else if(playbackSmokeStep==4&&state.ConfigBrightness==128&&pending==null){if(state.ConfigBrightness!=128||pending!=null)throw new Exception("brightness unconfirmed");SendCommand("interval 5",true);playbackSmokeStep++;}
    else if(playbackSmokeStep==5&&state.PeriodMs==5000&&pending==null){if(state.PeriodMs!=5000||pending!=null)throw new Exception("interval unconfirmed");SendCommand("play",true);playbackSmokeStep++;}
    else if(playbackSmokeStep==6&&state.VideoPlaying&&pending==null){if(!state.VideoPlaying||pending!=null)throw new Exception("resume unconfirmed");SaveScreenshot("ui_playback.png");SendCommand("fire",true);playbackSmokeStep++;}
    else if(playbackSmokeStep==7&&state.Emergency==1&&!state.VideoPlaying&&pending==null){if(state.Emergency!=1||state.VideoPlaying||!state.VideoMode)throw new Exception("video emergency priority");SendCommand("put_out",true);playbackSmokeStep++;}
    else if(playbackSmokeStep==8&&state.Emergency==0&&state.VideoPlaying&&pending==null){if(!state.VideoPlaying||state.ConfigVolume!=64||state.ConfigBrightness!=128||state.PeriodMs!=5000)throw new Exception("video restore");SendCommand("ads",true);playbackSmokeStep++;}
    else if(playbackSmokeStep==9&&!state.VideoMode&&pending==null){if(state.VideoMode||pending!=null||physicalPortEverOpened)throw new Exception("ads restore or isolation");System.IO.File.WriteAllText(System.IO.Path.Combine(captureDir,"playback_smoke.json"),new System.Web.Script.Serialization.JavaScriptSerializer().Serialize(new{passed=true,physical_port_opened=false,video=true,pause_resume=true,parameters=true,emergency_resume=true,returned_to_ads=true}));Close();}
   }catch(Exception e){System.IO.Directory.CreateDirectory(captureDir);System.IO.File.WriteAllText(System.IO.Path.Combine(captureDir,"playback_smoke.json"),e.ToString());Environment.ExitCode=1;Close();}
  }
 }
}
