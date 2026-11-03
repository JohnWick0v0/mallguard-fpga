// MallGuard 商场多媒体与应急显示终端 · Windows控制台
// 职责：素材检查与转换UI，操作用户选定电脑目录，不向开发板下载文件。
// 保留V5.1类/方法标识以兼容现有测试，文件名按产品职责组织。
using System;
using System.ComponentModel;
using System.Drawing;
using System.IO;
using System.Text;
using System.Windows.Forms;

namespace MallDisplayConsole {
 public sealed class MediaForm:Form {
  readonly string root;TextBox folder,source;ComboBox target;NumericUpDown start,duration;CheckBox loop;Label result;DataGridView grid;Button convert;
  public MediaForm(string applicationRoot,string initialFolder){
   root=applicationRoot;Text="素材检查与转换 · 仅操作选定目录";Font=Theme.Text(9);Size=new Size(1040,800);MinimumSize=new Size(820,650);StartPosition=FormStartPosition.CenterParent;BackColor=Theme.Page;
   TableLayoutPanel layout=new TableLayoutPanel{Dock=DockStyle.Fill,Padding=new Padding(14),RowCount=4,ColumnCount=1};layout.RowStyles.Add(new RowStyle(SizeType.Absolute,48));layout.RowStyles.Add(new RowStyle(SizeType.Percent,100));layout.RowStyles.Add(new RowStyle(SizeType.Absolute,150));layout.RowStyles.Add(new RowStyle(SizeType.Absolute,46));Controls.Add(layout);
   FlowLayoutPanel top=new FlowLayoutPanel{Dock=DockStyle.Fill};top.Controls.Add(new Label{Text="素材目录",AutoSize=true,Margin=new Padding(0,8,8,0)});folder=new TextBox{Text=initialFolder,Width=480};top.Controls.Add(folder);Button browse=new Button{Text="浏览",Width=64};browse.Click+=delegate{using(FolderBrowserDialog d=new FolderBrowserDialog()){d.SelectedPath=folder.Text;if(d.ShowDialog(this)==DialogResult.OK)folder.Text=d.SelectedPath;}};top.Controls.Add(browse);
   Button scan=new Button{Text="检查27项",Width=90};scan.Click+=delegate{Scan();};top.Controls.Add(scan);Button export=new Button{Text="导出检查",Width=86};export.Click+=delegate{Export();};top.Controls.Add(export);layout.Controls.Add(top,0,0);
   grid=new DataGridView{Dock=DockStyle.Fill,ReadOnly=true,AllowUserToAddRows=false,RowHeadersVisible=false,BackgroundColor=Color.White,AutoSizeColumnsMode=DataGridViewAutoSizeColumnsMode.Fill,SelectionMode=DataGridViewSelectionMode.FullRowSelect};foreach(string name in new[]{"文件","类型","状态","说明"})grid.Columns.Add(name,name);grid.Columns[0].FillWeight=24;grid.Columns[1].FillWeight=16;grid.Columns[2].FillWeight=12;grid.Columns[3].FillWeight=75;layout.Controls.Add(grid,0,1);
   FlowLayoutPanel tools=new FlowLayoutPanel{Dock=DockStyle.Fill,FlowDirection=FlowDirection.LeftToRight,WrapContents=true,Padding=new Padding(0,12,0,0)};
   tools.Controls.Add(new Label{Text="转换输出",AutoSize=true,Margin=new Padding(0,6,8,0)});target=new ComboBox{Width=150,DropDownStyle=ComboBoxStyle.DropDownList};foreach(string n in MediaLibrary.Required())if(n.EndsWith(".BMP")||Array.IndexOf(MediaLibrary.Music,n)>=0)target.Items.Add(n);target.SelectedItem="MUSIC.WAV";tools.Controls.Add(target);
   source=new TextBox{Width=470,ReadOnly=true};tools.Controls.Add(source);Button choose=new Button{Text="选择源素材",Width=100};choose.Click+=delegate{using(OpenFileDialog d=new OpenFileDialog()){d.Filter="图片与音频|*.bmp;*.png;*.jpg;*.jpeg;*.mp3;*.wav;*.flac;*.ogg;*.m4a|所有文件|*.*";if(d.ShowDialog(this)==DialogResult.OK)source.Text=d.FileName;}};tools.Controls.Add(choose);tools.SetFlowBreak(choose,true);
   tools.Controls.Add(new Label{Text="起点（秒）",AutoSize=true,Margin=new Padding(0,10,4,0)});start=new NumericUpDown{Maximum=86400,DecimalPlaces=1,Width=85,Margin=new Padding(0,7,15,0)};tools.Controls.Add(start);
   tools.Controls.Add(new Label{Text="成品时长（秒）",AutoSize=true,Margin=new Padding(0,10,4,0)});duration=new NumericUpDown{Minimum=10,Maximum=300,Value=60,Width=75,Margin=new Padding(0,7,15,0)};tools.Controls.Add(duration);loop=new CheckBox{Text="首尾循环衔接（额外取2秒）",Checked=true,AutoSize=true,Margin=new Padding(0,10,14,0)};tools.Controls.Add(loop);
   convert=new Button{Text="转换并保存",Width=125,Height=29,Margin=new Padding(0,5,0,0)};convert.Click+=Convert;tools.Controls.Add(convert);
   Label help=new Label{Text="图片保持比例并补边为640×480；音乐生成标准48k/16位/单声道WAV。已有同名文件会备份到 .media_backups。VIDEO.BIN检查文件头与大小，完整CRC由板端或离线工具验证。",AutoSize=false,Width=940,Height=40,ForeColor=Theme.Muted,Margin=new Padding(0,12,0,0)};tools.Controls.Add(help);target.SelectedIndexChanged+=delegate{bool audio=target.Text.EndsWith(".WAV");start.Enabled=duration.Enabled=loop.Enabled=audio;};layout.Controls.Add(tools,0,2);
   result=new Label{Dock=DockStyle.Fill,ForeColor=Theme.Navy,Text="检查不会改写文件。转换保存到上方指定目录；请先选择电脑上的素材目录。"};layout.Controls.Add(result,0,3);
   Shown+=delegate{if(Directory.Exists(folder.Text))Scan();};
  }
  void Scan(){grid.Rows.Clear();int good=0;foreach(MediaItem item in MediaLibrary.Scan(folder.Text)){int i=grid.Rows.Add(item.Name,item.Group,item.Status,item.Detail);grid.Rows[i].DefaultCellStyle.ForeColor=item.Valid?Color.FromArgb(24,110,80):Color.FromArgb(175,61,53);if(item.Valid)good++;}result.Text=String.Format("格式通过 {0}/27；缺失或格式错误 {1} 项。",good,27-good);}
  void Export(){using(SaveFileDialog d=new SaveFileDialog{Filter="CSV|*.csv",FileName="素材检查.csv"}){if(d.ShowDialog(this)!=DialogResult.OK)return;StringBuilder b=new StringBuilder("文件,类型,状态,说明\r\n");foreach(MediaItem i in MediaLibrary.Scan(folder.Text))b.Append(Csv(i.Name)).Append(',').Append(Csv(i.Group)).Append(',').Append(Csv(i.Status)).Append(',').Append(Csv(i.Detail)).Append("\r\n");File.WriteAllText(d.FileName,b.ToString(),new UTF8Encoding(true));}}
  static string Csv(string s){return "\""+(s??"").Replace("\"","\"\"")+"\"";}
  void Convert(object sender,EventArgs e){
   if(!File.Exists(source.Text)){result.Text="请先选择源素材文件。";return;}
   string input=source.Text,output=Path.GetFullPath(folder.Text),name=target.Text;double from=(double)start.Value;int seconds=(int)duration.Value;bool seamless=loop.Checked;
   convert.Enabled=false;result.Text="正在转换，请稍候；此操作不会访问开发板串口。";
   BackgroundWorker worker=new BackgroundWorker();worker.DoWork+=delegate{if(name.EndsWith(".BMP"))MediaConverter.Image(input,output,name);else MediaConverter.Audio(Path.Combine(root,"tools","ffmpeg.exe"),input,output,name,from,seconds,seamless);};
   worker.RunWorkerCompleted+=delegate(object s,RunWorkerCompletedEventArgs args){convert.Enabled=true;if(args.Error!=null){result.Text="转换失败："+args.Error.Message;return;}Scan();result.Text="已生成 "+name+"，格式校验通过。目录："+output;};worker.RunWorkerAsync();
  }
 }
}
