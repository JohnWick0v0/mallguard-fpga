// MallGuard 商场多媒体与应急显示终端 · Windows控制台
// 职责：仪表卡片、配色和趋势等复用UI控件。
// 保留V5.1类/方法标识以兼容现有测试，文件名按产品职责组织。
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace MallDisplayConsole {
    public static class Theme {
        public static readonly Color Navy=Color.FromArgb(19,38,62),Blue=Color.FromArgb(41,95,215),Muted=Color.FromArgb(107,121,141),Border=Color.FromArgb(225,231,240),Page=Color.FromArgb(242,245,250);
        public static Font Text(float size,bool bold=false){return new Font("Microsoft YaHei UI",size,bold?FontStyle.Bold:FontStyle.Regular);}
        public static GraphicsPath Round(Rectangle r,int radius){GraphicsPath p=new GraphicsPath();int d=radius*2;p.AddArc(r.Left,r.Top,d,d,180,90);p.AddArc(r.Right-d,r.Top,d,d,270,90);p.AddArc(r.Right-d,r.Bottom-d,d,d,0,90);p.AddArc(r.Left,r.Bottom-d,d,d,90,90);p.CloseFigure();return p;}
        public static Label Label(string text,float size,Color color,bool bold=false){return new Label{Text=text,AutoSize=false,AutoEllipsis=true,Font=Text(size,bold),ForeColor=color,BackColor=Color.Transparent,TextAlign=ContentAlignment.MiddleLeft};}
    }
    public class Card:Panel {
        public Color Accent=Color.Empty;
        public Card(){DoubleBuffered=true;BackColor=Color.White;Padding=new Padding(14);Margin=new Padding(0,0,10,10);}
        protected override void OnPaint(PaintEventArgs e){base.OnPaint(e);using(Pen p=new Pen(Theme.Border))e.Graphics.DrawRectangle(p,0,0,Width-1,Height-1);if(!Accent.IsEmpty)using(Brush b=new SolidBrush(Accent))e.Graphics.FillRectangle(b,0,0,Width,3);}
    }
    public class ActionButton:Button {
        public ActionButton(string text,Color color,bool filled){Text=text;Font=Theme.Text(9,true);Height=34;Cursor=Cursors.Hand;FlatStyle=FlatStyle.Flat;FlatAppearance.BorderSize=filled?0:1;FlatAppearance.BorderColor=Theme.Border;BackColor=filled?color:Color.White;ForeColor=filled?Color.White:color;UseVisualStyleBackColor=false;Margin=new Padding(0,0,6,0);}
    }
    public sealed class MetricCard:Card {
        readonly Label title,value,note;
        public MetricCard(string name){Padding=new Padding(12,8,10,6);title=Theme.Label(name,8.5f,Theme.Muted);value=Theme.Label("—",20,Theme.Navy,true);note=Theme.Label("等待设备回传",8,Theme.Muted);title.Dock=DockStyle.Top;title.Height=18;note.Dock=DockStyle.Bottom;note.Height=18;value.Dock=DockStyle.Fill;Controls.Add(value);Controls.Add(note);Controls.Add(title);}
        public void UpdateValue(string heading,string text,string detail,bool fresh){title.Text=heading;if(value.Text!=text){value.Font.Dispose();value.Font=Theme.Text(text.Length>8?14:20,true);}value.Text=text;value.ForeColor=fresh?Theme.Navy:Theme.Muted;note.Text=detail;}
    }
    public sealed class TrendPoint {public DateTime Time;public int V,L;}
    public sealed class TrendView:Control {
        public readonly List<TrendPoint> Points=new List<TrendPoint>();
        public TrendView(){DoubleBuffered=true;BackColor=Color.White;Dock=DockStyle.Fill;}
        protected override void OnPaint(PaintEventArgs e){base.OnPaint(e);Graphics g=e.Graphics;g.SmoothingMode=SmoothingMode.AntiAlias;Rectangle r=new Rectangle(56,48,Math.Max(40,Width-90),Math.Max(40,Height-100));using(Font f=Theme.Text(9))using(Brush b=new SolidBrush(Theme.Muted)){
          g.DrawString("输出音量 / 亮度 · 最近 120 秒（参数趋势，并非音频波形）",f,b,16,12);
          for(int i=0;i<=4;i++){float y=r.Bottom-r.Height*i/4f;using(Pen p=new Pen(Theme.Border))g.DrawLine(p,r.Left,y,r.Right,y);g.DrawString((i*25).ToString()+"%",f,b,10,y-8);}
          if(Points.Count<2){g.DrawString("等待有效的 v20 状态回传",f,b,r.Left+20,r.Top+30);return;}
          DateTime end=Points[Points.Count-1].Time;for(int series=0;series<2;series++)using(Pen pen=new Pen(series==0?Theme.Blue:Color.FromArgb(25,154,138),2)){
            PointF? previous=null;DateTime prevTime=DateTime.MinValue;foreach(TrendPoint p in Points){double age=(end-p.Time).TotalSeconds;if(age>120)continue;PointF pt=new PointF((float)(r.Right-r.Width*age/120.0),r.Bottom-r.Height*(series==0?p.V:p.L)/100f);if(previous.HasValue && (p.Time-prevTime).TotalSeconds<2.5)g.DrawLine(pen,previous.Value,pt);previous=pt;prevTime=p.Time;}
          }
          g.DrawString("−120 秒",f,b,r.Left,r.Bottom+12);g.DrawString("当前",f,b,r.Right-32,r.Bottom+12);using(Brush v=new SolidBrush(Theme.Blue))g.DrawString("● 音量",f,v,r.Left+100,r.Bottom+12);using(Brush l=new SolidBrush(Color.FromArgb(25,154,138)))g.DrawString("● 亮度",f,l,r.Left+180,r.Bottom+12);
        }}
    }
}
