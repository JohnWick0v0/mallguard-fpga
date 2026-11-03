// MallGuard 商场多媒体与应急显示终端 · Windows控制台
// 职责：串口会话、实时仪表、操作回执与日志主窗体；断开/退出不自动解除应急。
// 保留V5.1类/方法标识以兼容现有测试，文件名按产品职责组织。
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.IO.Ports;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace MallDisplayConsole {
    public sealed class Preferences {public SerialSettings Serial=new SerialSettings();public string Assets="";public bool Record=true;}
    sealed class Inbound {public int Session;public byte[] Bytes;public string Fault;public DateTime When;}
    sealed class LogEntry {public DateTime When;public string Direction,Text,Hex;}
    public sealed partial class MainForm:Form {
        readonly string root,captureDir;readonly bool smoke;
        readonly ConcurrentQueue<Inbound> inbound=new ConcurrentQueue<Inbound>();
        readonly LineAssembler assembler=new LineAssembler();
        readonly List<LogEntry> logs=new List<LogEntry>();
        readonly Dictionary<string,LegacyUpdate> legacy=new Dictionary<string,LegacyUpdate>();
        readonly Dictionary<string,DateTime> legacyTimes=new Dictionary<string,DateTime>();
        readonly MetricCard[] metrics=new MetricCard[6];
        readonly Button[] startButtons=new Button[5],endButtons=new Button[5];
        readonly Label[] eventHints=new Label[5];
        readonly Color[] colors={Theme.Blue,Color.FromArgb(209,61,74),Color.FromArgb(169,119,35),Color.FromArgb(39,98,185),Color.FromArgb(158,126,19)};
        ComboBox portBox,baudBox,bitsBox,parityBox,stopBox,flowBox,commandBox,filterBox;
        CheckBox dtrBox,rtsBox,crlfBox,hexBox,recordBox,pauseBox;
        Button connectButton,demoButton,refreshButton,defaultsButton,endCurrent,sendButton;
        Label linkLabel,protocolLabel,lastLabel,countersLabel,headerStatus,pendingLabel,previewCaption,previewSource;
        PictureBox preview;DataGridView logGrid,eventGrid;TrendView trend;
        readonly System.Windows.Forms.Timer timer=new System.Windows.Forms.Timer();
        readonly ToolTip tips=new ToolTip();
        SerialLink link;Preferences prefs;BoardState state,demoState;PendingCommand pending;
        StreamWriter recording;long recordBytes,rxBytes,txBytes,validFrames,badFrames;int session,queued,recordPart;string recordBase,previewPath="";
        bool demo,closing,refreshing;DateTime lastRx=DateTime.MinValue,lastValid=DateTime.MinValue,lastDemo=DateTime.MinValue;
        int lastAlarm=-1,smokeStep;DateTime smokeStart,smokePauseStart;bool physicalPortEverOpened;

        public MainForm(bool demoStart,bool smokeTest,string captures) {
            root=AppDomain.CurrentDomain.BaseDirectory;smoke=smokeTest;captureDir=captures;
            Text="商场应急显示屏控制台 v5.1 · HX4S20C";Font=Theme.Text(9);BackColor=Theme.Page;AutoScaleMode=AutoScaleMode.Dpi;
            MinimumSize=new Size(1080,760);Rectangle area=Screen.PrimaryScreen.WorkingArea;Size=new Size(Math.Min(1440,area.Width-60),Math.Min(960,area.Height-60));StartPosition=FormStartPosition.CenterScreen;
            if(smoke){ShowInTaskbar=false;StartPosition=FormStartPosition.Manual;Location=new Point(-4000,-4000);Size=new Size(1440,960);}
            LoadPreferences();BuildInterface();ApplyPreferences();
            timer.Interval=50;timer.Tick+=Tick;timer.Start();
            Shown+=delegate {RefreshPorts();if(demoStart||smoke)StartDemo();if(smoke){smokeStart=DateTime.UtcNow;if(FinderSmokeEnabled)StartFinderSmoke();}};
            FormClosing+=delegate {StopObservation();closing=true;timer.Stop();Disconnect();if(!smoke)SavePreferences();if(preview.Image!=null)preview.Image.Dispose();};
            AddLog("INFO","控制台已启动。固定应急按钮发送完整 ASCII 命令及 CRLF；显示数值仅来自设备回传。",null);
        }
        void LoadPreferences(){prefs=new Preferences();string p=Path.Combine(root,"data","settings.json");try{if(File.Exists(p))prefs=new JavaScriptSerializer().Deserialize<Preferences>(File.ReadAllText(p,Encoding.UTF8))??new Preferences();}catch{}if(prefs.Serial==null)prefs.Serial=new SerialSettings();if(String.IsNullOrEmpty(prefs.Assets))prefs.Assets=Path.Combine(root,"assets");}
        void SavePreferences(){try{prefs.Serial=ReadSettings();string folder=Path.Combine(root,"data");Directory.CreateDirectory(folder);string target=Path.Combine(folder,"settings.json"),temp=target+".tmp";File.WriteAllText(temp,new JavaScriptSerializer().Serialize(prefs),Encoding.UTF8);if(File.Exists(target))File.Replace(temp,target,null);else File.Move(temp,target);}catch(Exception e){AddLog("WARN","设置保存失败："+e.Message,null);}}
        ComboBox Combo(string[] values){ComboBox c=new ComboBox{DropDownStyle=ComboBoxStyle.DropDownList,Font=Theme.Text(9),Dock=DockStyle.Fill,Margin=new Padding(0,4,0,4)};c.Items.AddRange(values);if(c.Items.Count>0)c.SelectedIndex=0;return c;}
        void AddSetting(TableLayoutPanel grid,string label,Control value){int row=grid.RowCount++;grid.RowStyles.Add(new RowStyle(SizeType.Absolute,38));Label l=Theme.Label(label,9,Theme.Muted);l.Dock=DockStyle.Fill;grid.Controls.Add(l,0,row);grid.Controls.Add(value,1,row);}
        Button Button(string text,Color c,bool fill){return new ActionButton(text,c,fill);}
        void BuildInterface(){
            Panel header=new Panel{Dock=DockStyle.Top,Height=68,BackColor=Theme.Navy,Padding=new Padding(22,10,20,8)};
            Label title=Theme.Label("MALL DISPLAY  /  商场应急控制台",16,Color.White,true);title.Dock=DockStyle.Left;title.Width=560;
            headerStatus=Theme.Label("未连接设备",10,Color.FromArgb(183,204,234));headerStatus.Dock=DockStyle.Fill;headerStatus.TextAlign=ContentAlignment.MiddleRight;header.Controls.Add(headerStatus);header.Controls.Add(title);
            Panel sidebar=new Panel{Dock=DockStyle.Left,Width=292,BackColor=Color.White,Padding=new Padding(18),AutoScroll=true};
            TableLayoutPanel left=new TableLayoutPanel{Dock=DockStyle.Top,AutoSize=true,ColumnCount=1,Padding=new Padding(0,0,0,14)};left.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
            Label serialTitle=Theme.Label("串口设置",13,Theme.Navy,true);serialTitle.Height=32;serialTitle.Dock=DockStyle.Fill;left.Controls.Add(serialTitle);
            TableLayoutPanel settings=new TableLayoutPanel{Dock=DockStyle.Top,AutoSize=true,ColumnCount=2,RowCount=0};settings.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,66));settings.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
            portBox=new ComboBox{Dock=DockStyle.Fill,DropDownStyle=ComboBoxStyle.DropDownList,Margin=new Padding(0,4,0,4),DropDownWidth=440};
            baudBox=Combo(new[]{"115200","9600","19200","38400","57600","230400","460800","921600"});bitsBox=Combo(new[]{"8","7","6","5"});
            parityBox=Combo(new[]{"None","Odd","Even","Mark","Space"});stopBox=Combo(new[]{"One","Two","OnePointFive"});flowBox=Combo(new[]{"None","XOnXOff","RequestToSend","RequestToSendXOnXOff"});
            AddSetting(settings,"端  口",portBox);AddSetting(settings,"波特率",baudBox);AddSetting(settings,"数据位",bitsBox);AddSetting(settings,"校验位",parityBox);AddSetting(settings,"停止位",stopBox);AddSetting(settings,"流  控",flowBox);left.Controls.Add(settings);
            FlowLayoutPanel signals=new FlowLayoutPanel{Height=30,Dock=DockStyle.Fill};dtrBox=new CheckBox{Text="DTR",AutoSize=true};rtsBox=new CheckBox{Text="RTS",AutoSize=true};signals.Controls.Add(dtrBox);signals.Controls.Add(rtsBox);left.Controls.Add(signals);
            flowBox.SelectedIndexChanged+=delegate{rtsBox.Enabled=!IsConnected && !flowBox.Text.StartsWith("RequestToSend",StringComparison.Ordinal);};
            FlowLayoutPanel actions=new FlowLayoutPanel{Height=43,Dock=DockStyle.Fill};refreshButton=Button("刷新端口",Theme.Blue,false);refreshButton.Width=106;Button defaults=Button("板端默认",Theme.Blue,false);defaultsButton=defaults;defaults.Width=106;actions.Controls.Add(refreshButton);actions.Controls.Add(defaults);left.Controls.Add(actions);
            refreshButton.Click+=delegate{RefreshPorts();};defaults.Click+=delegate{baudBox.Text="115200";bitsBox.Text="8";parityBox.Text="None";stopBox.Text="One";flowBox.Text="None";dtrBox.Checked=false;rtsBox.Checked=false;};
            connectButton=Button("连接设备",Theme.Blue,true);connectButton.Dock=DockStyle.Fill;connectButton.Height=40;connectButton.Click+=delegate{if(IsConnected)Disconnect();else Connect();};left.Controls.Add(connectButton);
            demoButton=Button("离线演示 · 不连接硬件",Theme.Blue,false);demoButton.Dock=DockStyle.Fill;demoButton.Height=36;demoButton.Margin=new Padding(0,9,0,12);demoButton.Click+=delegate{if(demo)Disconnect();else StartDemo();};left.Controls.Add(demoButton);
            linkLabel=Theme.Label("● 未连接",11,Theme.Muted,true);linkLabel.Dock=DockStyle.Fill;linkLabel.Height=32;left.Controls.Add(linkLabel);
            protocolLabel=Theme.Label("等待串口状态数据",9,Theme.Muted);protocolLabel.Dock=DockStyle.Fill;protocolLabel.Height=48;left.Controls.Add(protocolLabel);
            lastLabel=Theme.Label("最近回传：—",8.5f,Theme.Muted);lastLabel.Dock=DockStyle.Fill;lastLabel.Height=30;left.Controls.Add(lastLabel);
            countersLabel=Theme.Label("RX 0 B  /  TX 0 B",8.5f,Theme.Muted);countersLabel.Dock=DockStyle.Fill;countersLabel.Height=42;left.Controls.Add(countersLabel);
            recordBox=new CheckBox{Text="自动记录通信日志",Checked=true,AutoSize=true,Margin=new Padding(0,8,0,8)};recordBox.CheckedChanged+=delegate{prefs.Record=recordBox.Checked;if(!IsConnected)return;if(recordBox.Checked)OpenRecording();else CloseRecording();};left.Controls.Add(recordBox);
            Label note=Theme.Label("板端默认：115200 / 8N1 / 无流控\n\nv27：详细加载阶段 / 文件 / 底层错误。\nv25：回执、时段、素材与验收。\nv20：参数监控；v19：变化通知。\n\n外接 USB-TTL：TX → FPGA F12\nRX ← FPGA D12，并连接 GND。\n\n软件不会因断开或退出自动结束告警。",8.5f,Theme.Muted);note.Dock=DockStyle.Fill;note.Height=190;left.Controls.Add(note);sidebar.Controls.Add(left);
            Panel scroll=new Panel{Dock=DockStyle.Fill,AutoScroll=true,Padding=new Padding(18,12,10,10),BackColor=Theme.Page};
            TableLayoutPanel body=new TableLayoutPanel{Dock=DockStyle.Top,Height=810,ColumnCount=1,RowCount=3,Margin=new Padding(0)};body.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));body.RowStyles.Add(new RowStyle(SizeType.Absolute,250));body.RowStyles.Add(new RowStyle(SizeType.Absolute,250));body.RowStyles.Add(new RowStyle(SizeType.Percent,100));
            scroll.Controls.Add(body);scroll.Resize+=delegate{body.Height=Math.Max(810,scroll.ClientSize.Height-24);};
            body.Controls.Add(BuildTelemetry(),0,0);body.Controls.Add(BuildActionTabs(),0,1);body.Controls.Add(BuildLogs(),0,2);
            Controls.Add(scroll);Controls.Add(sidebar);Controls.Add(header);
        }
        Control BuildTelemetry(){
            Panel p=new Panel{Dock=DockStyle.Fill};Label title=Theme.Label("屏幕信息",12,Theme.Navy,true);title.Dock=DockStyle.Top;title.Height=30;
            Panel previewPanel=new Card{Dock=DockStyle.Right,Width=226,Padding=new Padding(8),Margin=new Padding(0)};
            previewCaption=Theme.Label("本地素材预览",8.5f,Theme.Navy,true);previewCaption.Dock=DockStyle.Top;previewCaption.Height=24;
            previewSource=Theme.Label("本地参考，非HDMI截图",8,Theme.Muted);previewSource.Dock=DockStyle.Bottom;previewSource.Height=22;
            Button folder=Button("选择素材目录",Theme.Blue,false);folder.Dock=DockStyle.Bottom;folder.Height=28;folder.Click+=ChooseAssets;
            preview=new PictureBox{Dock=DockStyle.Fill,BackColor=Theme.Navy,SizeMode=PictureBoxSizeMode.Zoom};previewPanel.Controls.Add(preview);previewPanel.Controls.Add(folder);previewPanel.Controls.Add(previewSource);previewPanel.Controls.Add(previewCaption);
            TableLayoutPanel cards=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=3,RowCount=2,Padding=new Padding(0,0,10,0)};for(int i=0;i<3;i++)cards.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,33.333f));for(int i=0;i<2;i++)cards.RowStyles.Add(new RowStyle(SizeType.Percent,50));
            string[] names={"广告图号","广告模式","轮播间隔","输出音量","输出亮度","设备状态"};for(int i=0;i<6;i++){metrics[i]=new MetricCard(names[i]){Dock=DockStyle.Fill};cards.Controls.Add(metrics[i],i%3,i/3);}
            Panel content=new Panel{Dock=DockStyle.Fill,Padding=new Padding(0,0,0,10)};content.Controls.Add(cards);content.Controls.Add(previewPanel);p.Controls.Add(content);p.Controls.Add(title);return p;
        }
        Control BuildEmergencies(){
            Panel p=new Panel{Dock=DockStyle.Fill};Panel heading=new Panel{Dock=DockStyle.Top,Height=34};Label title=Theme.Label("应急事件控制",12,Theme.Navy,true);title.Dock=DockStyle.Fill;
            endCurrent=Button("结束当前应急",Theme.Blue,false);endCurrent.Dock=DockStyle.Right;endCurrent.Width=132;endCurrent.Click+=delegate{if(Fresh && state.Emergency!=0)SendCommand(Protocol.Ends[state.Emergency],true);};heading.Controls.Add(title);heading.Controls.Add(endCurrent);
            TableLayoutPanel grid=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=4,RowCount=1};for(int i=0;i<4;i++)grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,25));
            string[] subtitles={"","红色光晕 · 119","白色光晕 · OFF","深蓝光晕 · 110","黄色光晕 · 120"};
            for(int i=1;i<=4;i++){
                int id=i;Card c=new Card{Dock=DockStyle.Fill,Accent=colors[i],Padding=new Padding(12,8,12,10)};
                Label n=Theme.Label(Protocol.Names[i],12,colors[i],true);n.Dock=DockStyle.Top;n.Height=28;
                Label desc=Theme.Label(subtitles[i],8,Theme.Muted);desc.Dock=DockStyle.Top;desc.Height=22;
                eventHints[i]=Theme.Label("等待设备状态",8,Theme.Muted);eventHints[i].Dock=DockStyle.Bottom;eventHints[i].Height=22;
                FlowLayoutPanel buttons=new FlowLayoutPanel{Dock=DockStyle.Fill,FlowDirection=FlowDirection.TopDown,WrapContents=false,Padding=new Padding(0,4,0,0)};
                startButtons[i]=Button("触发"+new[]{"","火灾","停电","治安","医疗"}[i],colors[i],true);endButtons[i]=Button("结束 / 恢复",colors[i],false);startButtons[i].Width=148;endButtons[i].Width=148;startButtons[i].Height=30;endButtons[i].Height=28;endButtons[i].Margin=new Padding(0,4,0,0);
                startButtons[i].Click+=delegate{SendCommand(Protocol.Starts[id],true);};endButtons[i].Click+=delegate{SendCommand(Protocol.Ends[id],true);};buttons.Controls.Add(startButtons[i]);buttons.Controls.Add(endButtons[i]);
                buttons.Resize+=delegate{foreach(Control b in buttons.Controls)b.Width=Math.Max(90,buttons.ClientSize.Width-3);};
                c.Controls.Add(buttons);c.Controls.Add(eventHints[i]);c.Controls.Add(desc);c.Controls.Add(n);grid.Controls.Add(c,i-1,0);
            }
            p.Controls.Add(grid);p.Controls.Add(heading);return p;
        }
        DataGridView Grid(){return new DataGridView{Dock=DockStyle.Fill,ReadOnly=true,AllowUserToAddRows=false,AllowUserToDeleteRows=false,AllowUserToResizeRows=false,RowHeadersVisible=false,BackgroundColor=Color.White,BorderStyle=BorderStyle.None,SelectionMode=DataGridViewSelectionMode.FullRowSelect,AutoSizeColumnsMode=DataGridViewAutoSizeColumnsMode.Fill,ColumnHeadersHeight=30,RowTemplate={Height=25},DefaultCellStyle={Font=Theme.Text(8.5f),SelectionBackColor=Color.FromArgb(225,236,255),SelectionForeColor=Theme.Navy}};}
        Control BuildLogs(){
            Panel p=new Panel{Dock=DockStyle.Fill};pendingLabel=Theme.Label("指令状态：尚未发送。仅在收到板端状态后确认目标是否匹配。",8.5f,Theme.Muted);pendingLabel.Dock=DockStyle.Top;pendingLabel.Height=32;
            TabControl tabs=new TabControl{Dock=DockStyle.Fill,Font=Theme.Text(9)};TabPage logPage=new TabPage("通信日志"){BackColor=Color.White},trendPage=new TabPage("参数趋势"){BackColor=Color.White},eventPage=new TabPage("事件记录"){BackColor=Color.White};
            logGrid=Grid();logGrid.Columns.Add("time","时间");logGrid.Columns[0].FillWeight=20;logGrid.Columns.Add("dir","方向");logGrid.Columns[1].FillWeight=10;logGrid.Columns.Add("text","内容");logGrid.Columns[2].FillWeight=100;
            FlowLayoutPanel toolbar=new FlowLayoutPanel{Dock=DockStyle.Top,Height=38,Padding=new Padding(6,4,0,0)};filterBox=Combo(new[]{"全部","RX","TX","INFO","WARN"});filterBox.Dock=DockStyle.None;filterBox.Width=76;filterBox.Margin=new Padding(0,0,8,0);filterBox.SelectedIndexChanged+=delegate{RebuildLog();};
            pauseBox=new CheckBox{Text="暂停滚动",AutoSize=true,Margin=new Padding(0,5,8,0)};hexBox=new CheckBox{Text="HEX查看",AutoSize=true,Margin=new Padding(0,5,8,0)};hexBox.CheckedChanged+=delegate{RebuildLog();};
            Button clear=Button("清空",Theme.Blue,false),export=Button("导出 CSV",Theme.Blue,false);clear.Width=60;clear.Height=26;export.Width=90;export.Height=26;clear.Click+=delegate{logs.Clear();logGrid.Rows.Clear();};export.Click+=ExportLog;toolbar.Controls.AddRange(new Control[]{filterBox,pauseBox,hexBox,clear,export});
            Panel send=new Panel{Dock=DockStyle.Bottom,Height=68,Padding=new Padding(8,7,8,3)};
            FlowLayoutPanel bottom=new FlowLayoutPanel{Dock=DockStyle.Bottom,Height=24};crlfBox=new CheckBox{Text="追加 CRLF（固定应急按钮始终追加）",Checked=true,AutoSize=true};bottom.Controls.Add(crlfBox);
            sendButton=Button("发送",Theme.Blue,true);sendButton.Dock=DockStyle.Right;sendButton.Width=74;sendButton.Height=30;sendButton.Click+=delegate{SendCommand(commandBox.Text,false);};
            commandBox=new ComboBox{Dock=DockStyle.Fill,DropDownStyle=ComboBoxStyle.DropDown,Font=new Font("Consolas",10)};for(int i=1;i<=4;i++){commandBox.Items.Add(Protocol.Starts[i]);commandBox.Items.Add(Protocol.Ends[i]);}commandBox.Text="fire";commandBox.KeyDown+=delegate(object sender,KeyEventArgs e){if(e.KeyCode==Keys.Enter){e.SuppressKeyPress=true;SendCommand(commandBox.Text,false);}};
            send.Controls.Add(commandBox);send.Controls.Add(sendButton);send.Controls.Add(bottom);logPage.Controls.Add(logGrid);logPage.Controls.Add(send);logPage.Controls.Add(toolbar);
            trend=new TrendView();trendPage.Controls.Add(trend);
            eventGrid=Grid();eventGrid.Columns.Add("time","时间");eventGrid.Columns[0].FillWeight=25;eventGrid.Columns.Add("event","事件与确认");eventGrid.Columns[1].FillWeight=100;eventPage.Controls.Add(eventGrid);
            tabs.TabPages.AddRange(new[]{logPage,trendPage,eventPage});p.Controls.Add(tabs);p.Controls.Add(pendingLabel);return p;
        }
        void ApplyPreferences(){baudBox.Text=prefs.Serial.Baud.ToString();bitsBox.Text=prefs.Serial.DataBits.ToString();parityBox.Text=prefs.Serial.Parity;stopBox.Text=prefs.Serial.StopBits;flowBox.Text=prefs.Serial.Flow;dtrBox.Checked=prefs.Serial.Dtr;rtsBox.Checked=prefs.Serial.Rts;recordBox.Checked=prefs.Record;}
        SerialSettings ReadSettings(){PortChoice choice=portBox.SelectedItem as PortChoice;return new SerialSettings{Port=choice==null?prefs.Serial.Port:choice.Port,Baud=Int32.Parse(baudBox.Text),DataBits=Int32.Parse(bitsBox.Text),Parity=parityBox.Text,StopBits=stopBox.Text,Flow=flowBox.Text,Dtr=dtrBox.Checked,Rts=rtsBox.Checked};}
        bool IsConnected {get{return demo || (link!=null && link.IsOpen);}}
        bool Fresh {get{return IsConnected && state!=null && (DateTime.UtcNow-state.ReceivedUtc).TotalSeconds<2;}}
        void RefreshPorts(){
            if(refreshing||IsConnected)return;refreshing=true;refreshButton.Enabled=false;
            string wanted=portBox.SelectedItem is PortChoice ? ((PortChoice)portBox.SelectedItem).Port:prefs.Serial.Port;
            ThreadPool.QueueUserWorkItem(delegate {
                List<PortChoice> ports;try{ports=SerialLink.Ports();}catch{ports=new List<PortChoice>();}
                if(closing||IsDisposed||!IsHandleCreated)return;
                try{BeginInvoke((Action)delegate{refreshing=false;if(closing||IsConnected)return;portBox.Items.Clear();foreach(PortChoice p in ports)portBox.Items.Add(p);if(ports.Count>0){portBox.SelectedIndex=0;foreach(PortChoice p in ports)if(p.Port==wanted)portBox.SelectedItem=p;}refreshButton.Enabled=!IsConnected;AddLog("INFO","发现 "+ports.Count+" 个串口。",null);});}catch(InvalidOperationException){}
            });
        }
        void ResetSession(){StopGuided("会话重置");lastManual=null;demoLoadTicks=demoSaveTicks=0;demoSlot=-1;demoQueuedSlot=false;CancelFinderUpload();session++;Inbound discarded;while(inbound.TryDequeue(out discarded)){}Interlocked.Exchange(ref queued,0);assembler.Reset();state=null;legacy.Clear();legacyTimes.Clear();pending=null;lastRx=lastValid=DateTime.MinValue;lastAlarm=-1;rxBytes=txBytes=validFrames=badFrames=0;trend.Points.Clear();trend.Invalidate();previewPath="";}
        void Connect(){
            if(portBox.SelectedItem==null){AddLog("WARN","没有可用串口，请连接USB串口设备后刷新。",null);return;}
            try {
                ResetSession();SerialSettings settings=ReadSettings();SerialLink candidate=new SerialLink();int epoch=session;
                candidate.Received+=delegate(byte[] bytes){if(Interlocked.Increment(ref queued)>4096){Interlocked.Decrement(ref queued);return;}inbound.Enqueue(new Inbound{Session=epoch,Bytes=bytes,When=DateTime.UtcNow});};
                candidate.Failed+=delegate(string reason){inbound.Enqueue(new Inbound{Session=epoch,Fault=reason,When=DateTime.UtcNow});Interlocked.Increment(ref queued);};
                link=candidate;candidate.Open(settings);physicalPortEverOpened=true;prefs.Serial=settings;OpenRecording();
                AddLog("INFO","已打开 "+settings.Port+"，"+settings.Baud+" / "+settings.DataBits+settings.Parity[0]+" / "+settings.StopBits+"，流控 "+settings.Flow+"。",null);
                if(settings.Baud!=115200||settings.DataBits!=8||settings.Parity!="None"||settings.StopBits!="One"||settings.Flow!="None")AddLog("WARN","设置与板端默认115200/8N1/无流控不同，可能无法正确通信。",null);
                SavePreferences();
            }catch(Exception e){if(link!=null){link.Dispose();link=null;}AddLog("WARN","连接失败："+e.Message,null);}
            UpdateDisplay();
        }
        void StartDemo(){
            if(IsConnected&&!demo)return;
            Disconnect();ResetSession();demo=true;demoState=new BoardState{Version=27,VideoFlags=4,ConfigFlags=8,LoadProgress=100,NoticeFlags=4,Picture=1,Auto=true,PeriodMs=10000,Volume=128,Brightness=192,ConfigVolume=128,ConfigBrightness=192,ReadyMask=15,BootReady=true};lastDemo=DateTime.MinValue;
            OpenRecording();AddLog("INFO","离线演示已启动：使用模拟状态，不打开任何物理串口。",null);UpdateDisplay();
        }
        void Disconnect(){StopGuided("连接断开或退出");CancelFinderUpload();
            bool was=IsConnected;if(was&&observation.Running)observation.ConnectionLosses++;if(pending!=null)pendingLabel.Text="指令尚未得到目标状态回传，连接已断开。";
            session++;demo=false;pending=null;if(link!=null){link.Dispose();link=null;}Inbound discarded;while(inbound.TryDequeue(out discarded)){}Interlocked.Exchange(ref queued,0);assembler.Reset();
            if(was)AddLog("INFO","连接已断开；未向开发板发送任何自动结束指令。",null);CloseRecording();if(!closing)UpdateDisplay();
        }
        void SendCommand(string text,bool fixedButton){
            if(guided.Running&&!guidedDispatch)StopGuided("用户手动发送操作");
            text=(text??"").Trim();if(!IsConnected){AddLog("WARN","请先连接设备或启动离线演示。",null);return;}
            if(TryFinderCommand(text))return;
            if(text.Length==0||text.Length>128){AddLog("WARN","指令长度应为1～128个ASCII字符。",null);return;}
            foreach(char c in text)if(c<32||c>126){AddLog("WARN","指令仅支持单行可打印ASCII字符。",null);return;}
            int interruptTarget;bool interruptEnd;
            if(finderBusy&&(text.Equals("found",StringComparison.OrdinalIgnoreCase)||(Protocol.CommandTarget(text.ToLowerInvariant(),out interruptTarget,out interruptEnd)&&!interruptEnd))){CancelFinderUpload();finderFeedback.Text="上传已停止，优先发送应急/关闭指令。";}
            bool commandEnding;int commandTarget;bool urgent=text=="found"||Protocol.CommandTarget(text.ToLowerInvariant(),out commandTarget,out commandEnding);
            if(pending!=null&&!urgent){AddLog("WARN","上一条操作仍在处理中，请等待结果；应急指令仍可优先发送。",null);return;}
            if((text.StartsWith("slot ",StringComparison.Ordinal)||text=="save")&&(!Fresh||state.Version<25)){AddLog("WARN","此操作需要配套V25固件及实时状态。",null);return;}
            byte[] bytes=Encoding.ASCII.GetBytes(text+((fixedButton||crlfBox.Checked)?"\r\n":""));
            try {
                if(!demo)link.Send(bytes);txBytes+=bytes.Length;TrackCommand(text,"已发送","等待开发板回传");AddLog("TX",text+((fixedButton||crlfBox.Checked)?" ⏎":""),bytes);
                int target;bool ending;if(text.Equals("found",StringComparison.OrdinalIgnoreCase)){CancelFinderUpload();BeginNoticeConfirmation(0,state==null?0:state.NoticeId,DateTime.UtcNow);}
                else if(Protocol.CommandTarget(text.ToLowerInvariant(),out target,out ending)) {
                    if(pending!=null)AddLog("INFO","上一条待确认指令被后续指令替代："+pending.Text,null);
                    pending=new PendingCommand{Text=text,Target=target,SentUtc=DateTime.UtcNow,PreviousSequence=state==null?(int?)null:state.Sequence,CommandCode=Protocol.CommandCode(text),PreviousReceipt=Fresh&&state.Version>=25?(int?)state.ReceiptSequence:null};
                    pendingLabel.Text="已发送 "+text+"；等待板端回传目标状态，尚未确认。";pendingLabel.ForeColor=Color.FromArgb(153,108,24);
                    AddEvent("已发送 "+text+"（待状态回传）");
                }else if(PlaybackTarget(text)!=null){pending=new PendingCommand{Text=text,Expected=PlaybackTarget(text),SentUtc=DateTime.UtcNow,PreviousSequence=state==null?(int?)null:state.Sequence,CommandCode=Protocol.CommandCode(text),PreviousReceipt=Fresh&&state.Version>=25?(int?)state.ReceiptSequence:null};pendingLabel.Text="已发送 "+text+"，等待板端状态匹配。";}
                else {pendingLabel.Text="已发送自定义数据；固件未必支持该指令。";AddLog("INFO","配套v23支持播放、参数、应急和寻人指令；未知指令不会改变板端状态。",null);}
                if(demo && (fixedButton||crlfBox.Checked))DemoCommand(text.ToLowerInvariant());
            }catch(Exception e){AddLog("WARN","发送失败："+e.Message,null);pendingLabel.Text="发送失败，未确认执行。";StopGuided("串口发送失败："+e.Message);}
        }
        void DemoCommand(string command){DemoExperienceCommand(command);if(demoState.ReceiptCommand<0x20&&(demoState.ReceiptStatus==1||demoState.ReceiptStatus==2))return;DemoPlayback(command);if(command=="found"){demoState.NoticeKind=0;demoState.NoticeFlags=5;}for(int i=1;i<=4;i++){if(command==Protocol.Starts[i]&&demoState.Emergency==0)demoState.Emergency=i;else if(command==Protocol.Ends[i]&&demoState.Emergency==i)demoState.Emergency=0;}demoState.Volume=demoState.Emergency==0?demoState.ConfigVolume:demoState.Emergency==2?0:255;demoState.Brightness=demoState.Emergency==0?demoState.ConfigBrightness:255;}
        void Tick(object sender,EventArgs args){
            if(closing)return;DateTime now=DateTime.UtcNow;
            if(demo && (now-lastDemo).TotalMilliseconds>=250){lastDemo=now;DemoVideoTick();DemoExperienceTick();demoState.Sequence=(demoState.Sequence+1)&65535;if(demoState.Emergency==0&&!demoState.VideoMode&&!demoState.Loading&&demoState.Auto&&(demoState.Sequence%40)==0)demoState.Picture=demoState.Picture%4+1;byte[] frame=Encoding.ASCII.GetBytes(Protocol.Frame(demoState));inbound.Enqueue(new Inbound{Session=session,Bytes=frame,When=now});Interlocked.Increment(ref queued);}
            Inbound item;int budget=128;
            while(budget-->0&&inbound.TryDequeue(out item)){
                Interlocked.Decrement(ref queued);if(item.Session!=session)continue;
                if(item.Fault!=null){AddLog("WARN","串口掉线："+item.Fault,null);Disconnect();continue;}
                rxBytes+=item.Bytes.Length;lastRx=item.When;
                int dropped=assembler.DroppedLines;foreach(string line in assembler.Feed(item.Bytes))ReceiveLine(line,item.When);
                if(dropped!=assembler.DroppedLines)AddLog("WARN","接收行超过512字节，已丢弃该行并等待换行重新同步。",null);
            }
            if(pending!=null&&(now-pending.SentUtc).TotalSeconds>pending.TimeoutSeconds){pendingLabel.Text="未收到目标状态确认："+pending.Text+"（不会自动重发；已排队操作仍可能随后执行）。";pendingLabel.ForeColor=Color.FromArgb(153,108,24);AddLog("WARN",pendingLabel.Text,null);AddEvent(pending.Text+"：目标状态未确认");TrackCommand(pending.Text,"未确认",pendingLabel.Text);GuidedResult(pending.Text,false,"步骤超时，目标状态未确认；不自动重发");pending=null;}
            UpdateDisplay();UpdateFinder();UpdatePlayback();UpdateExperience();UpdateGuided(now);if(smoke){if(GuidedSmokeEnabled)GuidedSmokeTick(now);else if(ExperienceSmokeEnabled)ExperienceSmokeTick(now);else if(PlaybackSmokeEnabled)PlaybackSmokeTick(now);else if(FinderSmokeEnabled)FinderSmokeTick(now);else SmokeTick(now);}
        }
        void ReceiveLine(string line,DateTime when){
            AddLog("RX",line,Encoding.GetEncoding(28591).GetBytes(line));BoardState received;string reason;
            if(Protocol.TryState(line,out received,out reason)){
                received.ReceivedUtc=when;
                bool bootEdge=state!=null&&state.BootReady&&!received.BootReady;
                if(state!=null&&state.Version==received.Version&&state.Sequence==received.Sequence&&!bootEdge){badFrames++;if(observation.Running)observation.InvalidFrames++;AddLog("WARN","重复序号状态已丢弃；不刷新通信有效期。",null);return;}
                if(state!=null&&(((received.Sequence-state.Sequence)&65535)>32768||state.Version!=received.Version||bootEdge)){
                    bool expectedSlot=state.Version==received.Version&&pending!=null&&pending.ObserveSlotRestart(received);
                    if(expectedSlot){pendingLabel.Text="切换时段：开发板正在重新初始化，等待目标素材加载完成。";TrackCommand(pending.Text,"重新初始化",pendingLabel.Text);AddLog("INFO",pendingLabel.Text,null);}
                    else{StopGuided("设备重启或协议切换");if(pending!=null){TrackCommand(pending.Text,"未确认","设备重启或协议切换；不自动重发");pending=null;}}
                    lastManual=null;
                }
                received.ReceivedUtc=when;state=received;ConfirmFinder(received);ReceiveExperience(received);lastValid=when;validFrames++;
                if(lastAlarm!=state.Emergency){AddEvent("板端回传："+Protocol.Names[state.Emergency]);lastAlarm=state.Emergency;}
                if(pending!=null)pending.Observe(received);
                if(pending!=null&&pending.CommandCode==12&&pending.LoadingSeen&&received.LoadFailed){pendingLabel.Text="加载失败，已保留上一完整画面："+pending.Text;pendingLabel.ForeColor=Color.FromArgb(175,61,53);TrackCommand(pending.Text,"加载失败",pendingLabel.Text);AddLog("WARN",pendingLabel.Text,null);GuidedResult(pending.Text,false,pendingLabel.Text);pending=null;}
                if(pending!=null&&pending.Rejected(received)){pendingLabel.Text=Protocol.ReceiptReason(received.ReceiptStatus)+"："+pending.Text;pendingLabel.ForeColor=Color.FromArgb(175,61,53);TrackCommand(pending.Text,"被拒绝",pendingLabel.Text);AddLog("WARN",pendingLabel.Text,null);GuidedResult(pending.Text,false,pendingLabel.Text);pending=null;}
                if(pending!=null&&!pending.Accepted&&pending.ReceiptMatches(received)){pending.Accepted=true;pendingLabel.Text=Protocol.ReceiptReason(received.ReceiptStatus)+"："+pending.Text+"；等待目标生效。";TrackCommand(pending.Text,received.ReceiptStatus==5?"已排队":"已接受",pendingLabel.Text);}
                if(pending!=null && pending.Matched(received)){pendingLabel.Text=pending.SlotRestartObserved?"已生效："+pending.Text+"（重新初始化后，目标时段及加载完成状态确认）":received.Version>=25?"已生效："+pending.Text+"（开发板回执及目标状态均确认）":"板端后续状态已匹配 "+pending.Text+" 的目标（旧协议状态确认）。";TrackCommand(pending.Text,"已生效",pendingLabel.Text);pendingLabel.ForeColor=Color.FromArgb(20,132,104);AddEvent(pending.Text+"：目标状态已匹配");GuidedResult(pending.Text,true,pendingLabel.Text);pending=null;}
                trend.Points.Add(new TrendPoint{Time=when,V=Protocol.Percent(state.Volume),L=Protocol.Percent(state.Brightness)});while(trend.Points.Count>500)trend.Points.RemoveAt(0);trend.Invalidate();
            } else if(reason!=null){badFrames++;if(observation.Running)observation.InvalidFrames++;AddLog("WARN",reason+"，未更新状态。",null);}
            else {LegacyUpdate update;if(Protocol.TryLegacy(line,out update)){legacy[update.Kind]=update;legacyTimes[update.Kind]=when;lastValid=when;}else if(line=="MEDIA PLAYER READY"){legacy.Clear();legacyTimes.Clear();state=null;lastAlarm=-1;AddLog("INFO","收到旧版启动消息；等待变化通知，初始参数未知。",null);}}
        }
        void UpdateDisplay(){
            bool connected=IsConnected,fresh=Fresh;DateTime now=DateTime.UtcNow;
            foreach(Control c in new Control[]{portBox,baudBox,bitsBox,parityBox,stopBox,flowBox,dtrBox,rtsBox})c.Enabled=!connected;rtsBox.Enabled=!connected&&!flowBox.Text.StartsWith("RequestToSend",StringComparison.Ordinal);
            refreshButton.Enabled=!connected&&!refreshing;defaultsButton.Enabled=!connected;connectButton.Text=demo?"结束演示":connected?"断开连接":"连接设备";demoButton.Enabled=!connected||demo;demoButton.Text=demo?"结束离线演示":"离线演示 · 不连接硬件";sendButton.Enabled=connected;endCurrent.Enabled=fresh&&state.Emergency!=0;
            bool legacyMode=state==null&&legacy.Count>0;
            string status=!connected?"未连接":demo?"演示模式 · 模拟数据":fresh?"已连接 · 状态实时":legacyMode?"已连接 · v19变化通知":"已连接 · 等待有效回传";
            if(connected&&state!=null&&!fresh)status="已连接 · 回传超时";
            headerStatus.Text=(demo?"● 演示：不连接硬件  |  ":"")+status+"  ·  "+DateTime.Now.ToString("HH:mm:ss");
            linkLabel.Text="● "+status;linkLabel.ForeColor=fresh?Theme.Blue:Theme.Muted;
            protocolLabel.Text=state!=null?"协议 v"+state.Version+" / XOR校验\n"+(fresh?"250 ms周期状态":"状态超过2秒，以下数值为历史值"):legacyMode?"v19兼容：仅参数变化时回传\n应急状态及未收到的参数未知":"配套v23固件可回传完整状态\n初始参数不作默认猜测";
            lastLabel.Text="最近回传："+(lastValid==DateTime.MinValue?"—":lastValid.ToLocalTime().ToString("HH:mm:ss.fff"));
            countersLabel.Text="RX "+rxBytes+" B  /  TX "+txBytes+" B\n有效状态 "+validFrames+"  /  坏包 "+badFrames;
            if(state!=null){
                string suffix=connected?(fresh?"板端回传":"过期历史值"):"连接已断开 · 历史值";
                string img=state.Emergency==0?"P"+state.Picture:Protocol.Images[state.Emergency];
                metrics[0].UpdateValue(state.Emergency==0?"广告图号":"应急页面",img,state.Emergency==0?(state.BootReady?suffix:"正在加载，图号仅为广告状态"):"广告 P"+state.Picture+" 待恢复 · "+suffix,fresh);
                metrics[1].UpdateValue("广告模式",state.Auto?"自动 A":"手动 E",state.Emergency!=0?"应急期间轮播暂停":suffix,fresh);
                metrics[2].UpdateValue("轮播间隔",(state.PeriodMs/1000.0).ToString("0.###")+" s",state.Emergency!=0?"广告计时已冻结":suffix,fresh);
                metrics[3].UpdateValue("输出音量",Protocol.Percent(state.Volume)+"%","广告配置 "+Protocol.Percent(state.ConfigVolume)+"% · 原值 "+state.Volume,fresh);
                metrics[4].UpdateValue("输出亮度",Protocol.Percent(state.Brightness)+"%","广告配置 "+Protocol.Percent(state.ConfigBrightness)+"% · 原值 "+state.Brightness,fresh);
                metrics[5].UpdateValue("设备状态",!state.BootReady?"加载中":Protocol.Names[state.Emergency],"E"+state.Error.ToString("X2")+" · "+Protocol.ErrorName(state.Error),fresh);
                if(state.Version>=25&&(state.Loading||state.CachedFrame)&&state.Emergency==0)previewCaption.Text="本地参考：上一完整画面 · "+(state.LoadFailed?"加载失败，等待重试":"新素材加载中");
                string prefix=new[]{"PIC","MOR","DAY","EVE"}[state.Slot];
                if(!(state.Version>=25&&(state.Loading||state.CachedFrame)&&state.Emergency==0))previewCaption.Text=state.VideoMode&&state.Emergency==0?"视频播放状态 · 非画面采集":"本地参考："+img;
                if(!(state.Version>=25&&(state.Loading||state.CachedFrame)&&state.Emergency==0))UpdatePreview(state.VideoMode&&state.Emergency==0?"VIDEO_PREVIEW.JPG":state.Emergency==0?prefix+state.Picture+".BMP":Protocol.Images[state.Emergency]);
                if(state.Version>=23){metrics[0].UpdateValue("当前内容",state.Emergency!=0?Protocol.Names[state.Emergency]:state.VideoMode?"VIDEO.BIN":"广告 P"+state.Picture,"投放："+new[]{"默认","早间","午间","晚间"}[state.Slot]+" · "+suffix,fresh);metrics[5].UpdateValue("运行状态",state.Emergency!=0?Protocol.Names[state.Emergency]:state.VideoMode?(state.VideoError!=0?"视频错误":!state.VideoLoaded?"视频预缓冲":state.VideoBuffering?"补充缓冲":state.VideoPlaying?"视频播放中":"视频暂停"):state.BootReady?"广告播放中":"图片加载中","E"+state.Error.ToString("X2")+" / VE"+state.VideoError.ToString("X2"),fresh);}
                if(state.Version>=25&&state.Emergency==0&&(state.Loading||state.LoadFailed))metrics[5].UpdateValue("运行状态",state.LoadFailed?"素材加载失败":"后台加载 "+state.LoadProgress+"%",state.CachedFrame?"保留上一完整画面":"准备缓存当前画面",fresh);

            }else{
                if(!legacy.ContainsKey("PIC")){if(preview.Image!=null){preview.Image.Dispose();preview.Image=null;}previewPath="";previewCaption.Text="等待设备图号";previewSource.Text="本地参考，非HDMI截图";}
                string[] h={"广告图号","广告模式","轮播间隔","广告音量","广告亮度","设备状态"};for(int i=0;i<6;i++)metrics[i].UpdateValue(h[i],"—",legacyMode?"旧版仅变化通知；未收到该参数":"等待设备回传",false);
                LegacyUpdate u;if(legacy.TryGetValue("PIC",out u)){bool f=connected&&(now-legacyTimes["PIC"]).TotalSeconds<2;metrics[0].UpdateValue(h[0],"P"+u.Value,"旧协议广告图号 · 应急状态未知",f);metrics[1].UpdateValue(h[1],u.Auto?"自动 A":"手动 E","旧协议最后一次通知",f);UpdatePreview("PIC"+u.Value+".BMP");}
                if(legacy.TryGetValue("PRD",out u))metrics[2].UpdateValue(h[2],(u.Value/1000.0).ToString("0.###")+" s","旧协议最后一次通知",false);
                if(legacy.TryGetValue("VOL",out u))metrics[3].UpdateValue(h[3],Protocol.Percent(u.Value)+"%","旧协议广告配置 · 实际输出未知",false);
                if(legacy.TryGetValue("BRT",out u))metrics[4].UpdateValue(h[4],Protocol.Percent(u.Value)+"%","旧协议广告配置 · 实际输出未知",false);
                if(legacy.TryGetValue("ERR",out u))metrics[5].UpdateValue(h[5],"E"+u.Value.ToString("X2"),Protocol.ErrorName(u.Value),false);
            }
            for(int i=1;i<=4;i++){
                startButtons[i].Enabled=connected&&(!fresh||state.Emergency==0);endButtons[i].Enabled=connected&&(!fresh||state.Emergency==i);
                eventHints[i].Text=!connected?"未连接":!fresh?"状态未确认，可手动发送":state.Emergency==i?"● 板端正在处理":state.Emergency!=0?"等待当前事件结束":(state.ReadyMask&(1<<(i-1)))!=0?"图片已就绪":"图片缺失，将使用备用页";
                eventHints[i].ForeColor=fresh&&state.Emergency==i?colors[i]:Theme.Muted;
            }
        }
        void ChooseAssets(object sender,EventArgs e){using(FolderBrowserDialog d=new FolderBrowserDialog()){d.Description="选择含PIC1.BMP和FIRE/POWER/SECURITY/MEDICAL.BMP的素材目录";d.SelectedPath=prefs.Assets;if(d.ShowDialog(this)==DialogResult.OK){prefs.Assets=d.SelectedPath;previewPath="";SavePreferences();UpdateDisplay();}}}
        void UpdatePreview(string name){string path=Path.Combine(prefs.Assets,name);if(path==previewPath)return;previewPath=path;if(preview.Image!=null){preview.Image.Dispose();preview.Image=null;}try{if(File.Exists(path))using(Image im=Image.FromFile(path))preview.Image=new Bitmap(im);}catch(Exception e){AddLog("WARN","本地预览读取失败："+e.Message,null);}previewSource.Text=preview.Image==null?"未找到本地素材 · 非实时视频":"本地参考图片 · 非实时HDMI视频";tips.SetToolTip(preview,path);}
        void AddEvent(string text){if(eventGrid==null)return;eventGrid.Rows.Add(DateTime.Now.ToString("HH:mm:ss.fff"),text);if(eventGrid.Rows.Count>500)eventGrid.Rows.RemoveAt(0);}
        void AddLog(string direction,string text,byte[] bytes){
            LogEntry e=new LogEntry{When=DateTime.Now,Direction=direction,Text=text,Hex=bytes==null?"":BitConverter.ToString(bytes).Replace('-',' ')};logs.Add(e);if(logs.Count>2000){logs.RemoveRange(0,250);if(logGrid!=null)RebuildLog();}else if(logGrid!=null&&Matches(e))AppendRow(e);
            if(recording!=null){try{string line=Csv(e.When.ToString("O"))+","+Csv(e.Direction)+","+Csv(e.Text)+","+Csv(e.Hex);recording.WriteLine(line);recording.Flush();recordBytes+=Encoding.UTF8.GetByteCount(line)+2;if(recordBytes>10*1024*1024){CloseRecording();recordPart++;OpenRecordingPart();}}catch{CloseRecording();}}
        }
        bool Matches(LogEntry e){return filterBox==null||filterBox.SelectedIndex<=0||filterBox.Text==e.Direction;}
        void AppendRow(LogEntry e){int row=logGrid.Rows.Add(e.When.ToString("HH:mm:ss.fff"),e.Direction,hexBox!=null&&hexBox.Checked&&!String.IsNullOrEmpty(e.Hex)?e.Hex:e.Text);logGrid.Rows[row].DefaultCellStyle.ForeColor=e.Direction=="TX"?Theme.Blue:e.Direction=="WARN"?Color.FromArgb(177,96,27):Theme.Navy;if(pauseBox!=null&&!pauseBox.Checked&&logGrid.Rows.Count>0)if(logGrid.IsHandleCreated && logGrid.DisplayedRowCount(false)>0)logGrid.FirstDisplayedScrollingRowIndex=logGrid.Rows.Count-1;}
        void RebuildLog(){if(logGrid==null)return;logGrid.Rows.Clear();foreach(LogEntry e in logs)if(Matches(e))AppendRow(e);}
        static string Csv(string value){value=value??"";if(value.Length>0&&"=+-@\t\r".IndexOf(value[0])>=0)value="'"+value;return "\""+value.Replace("\"","\"\"")+"\"";}
        void OpenRecording(){if(!prefs.Record||recording!=null)return;try{string folder=Path.Combine(root,smoke?"smoke-data":"data","logs");Directory.CreateDirectory(folder);recordBase=Path.Combine(folder,(demo?"demo_":"uart_")+DateTime.Now.ToString("yyyyMMdd_HHmmss_fff"));recordPart=0;OpenRecordingPart();}catch(Exception e){AddLog("WARN","自动记录无法启动："+e.Message,null);}}
        void OpenRecordingPart(){try{recording=new StreamWriter(recordBase+"_"+recordPart.ToString("D3")+".csv",false,new UTF8Encoding(true));recording.WriteLine("时间,方向,内容,HEX");recordBytes=0;recording.Flush();}catch{recording=null;}}
        void CloseRecording(){if(recording!=null){try{recording.Dispose();}catch{}recording=null;}}
        void ExportLog(object sender,EventArgs args){using(SaveFileDialog d=new SaveFileDialog{Filter="CSV 文件|*.csv",FileName="FPGA_UART_"+DateTime.Now.ToString("yyyyMMdd_HHmmss")+".csv",InitialDirectory=root})if(d.ShowDialog(this)==DialogResult.OK){try{using(StreamWriter w=new StreamWriter(d.FileName,false,new UTF8Encoding(true))){w.WriteLine("时间,方向,内容,HEX");foreach(LogEntry e in logs)w.WriteLine(Csv(e.When.ToString("O"))+","+Csv(e.Direction)+","+Csv(e.Text)+","+Csv(e.Hex));}AddLog("INFO","日志已导出："+d.FileName,null);}catch(Exception e){AddLog("WARN","导出失败："+e.Message,null);}}}
        void SaveScreenshot(string file){Directory.CreateDirectory(captureDir);using(Bitmap bitmap=new Bitmap(Width,Height)){DrawToBitmap(bitmap,new Rectangle(0,0,Width,Height));bitmap.Save(Path.Combine(captureDir,file),ImageFormat.Png);}}
        void SmokeTick(DateTime now){
            double seconds=(now-smokeStart).TotalSeconds;
            try {
                if(seconds>45)throw new Exception("Emergency UI stage timeout "+smokeStep);
                if(smokeStep==0&&Fresh&&state.Emergency==0&&pending==null){if(!Fresh||state.Emergency!=0)throw new Exception("demo telemetry missing");startButtons[1].PerformClick();smokeStep++;}
                else if(smokeStep==1&&Fresh&&state.Emergency==1&&pending==null){if(state.Emergency!=1||state.Volume!=255||startButtons[3].Enabled)throw new Exception("fire state/control gating wrong");SaveScreenshot("ui_emergency.png");endButtons[1].PerformClick();smokeStep++;}
                else if(smokeStep==2&&Fresh&&state.Emergency==0&&pending==null){startButtons[2].PerformClick();smokeStep++;}
                else if(smokeStep==3&&Fresh&&state.Emergency==2&&pending==null){if(state.Emergency!=2||state.Volume!=0)throw new Exception("power silence wrong");endButtons[2].PerformClick();smokeStep++;}
                else if(smokeStep==4&&Fresh&&state.Emergency==0&&pending==null){startButtons[3].PerformClick();smokeStep++;}
                else if(smokeStep==5&&Fresh&&state.Emergency==3&&pending==null){if(state.Emergency!=3)throw new Exception("security wrong");endButtons[3].PerformClick();smokeStep++;}
                else if(smokeStep==6&&Fresh&&state.Emergency==0&&pending==null){startButtons[4].PerformClick();smokeStep++;}
                else if(smokeStep==7&&Fresh&&state.Emergency==4&&pending==null){if(state.Emergency!=4)throw new Exception("medical wrong");endButtons[4].PerformClick();smokeStep++;}
                else if(smokeStep==8&&Fresh&&state.Emergency==0&&pending==null){if(state.Emergency!=0||state.Volume!=128||state.Brightness!=192||physicalPortEverOpened||pending!=null)throw new Exception("restore or physical isolation wrong");SaveScreenshot("ui_main.png");lastDemo=now.AddHours(1);smokePauseStart=now;smokeStep++;}
                else if(smokeStep==9&&(now-smokePauseStart).TotalSeconds>2.6){if(Fresh||!protocolLabel.Text.Contains("超过2秒")||endCurrent.Enabled)throw new Exception("stale state not marked");SaveScreenshot("ui_timeout.png");File.WriteAllText(Path.Combine(captureDir,"ui_smoke.json"),new JavaScriptSerializer().Serialize(new{passed=true,physical_port_opened=physicalPortEverOpened,valid_frames=validFrames,all_four_events=true,restored=true,stale_state_marked=true}),Encoding.UTF8);Close();}
            }catch(Exception e){Directory.CreateDirectory(captureDir);File.WriteAllText(Path.Combine(captureDir,"ui_smoke.json"),new JavaScriptSerializer().Serialize(new{passed=false,error=e.Message}),Encoding.UTF8);Environment.ExitCode=1;Close();}
        }
    }
}
