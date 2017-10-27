using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using System.Management;
using ThoughtWorks.QRCode.Codec;
using System.IO.Ports;
using System.IO;
using System.Text.RegularExpressions;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Formatters.Binary;
using System.Drawing.Imaging;

namespace HKMonitor
{
    public partial class Form1 : Form
    {
       
        private string filestr, strSql;
        private DataSet1 DS = new DataSet1();
        private string lid,stid,mac;
        private Single MaxScreenFontSize=20F;
        private string ShowAllScreen,SeqName;//ON 全屏显示 OFF 非全屏显示
        private Int32 SeqKind;//
        private string BarCode,ErCode;//扫码枪  二维码
        private Int32 SplitterDistance = 760;//分割符位置
        private Int32 width = 800, height=1000;
        private static Globals.CIniIFile iFile;
        ShowBund sub;//子窗体
        ShowList sub1;
        MITSUBISHILink mweight = null;
        private string sReceiveDatatemp = "";//串口临时数据

        //private enum SeqKind  //工艺类型
        //{
        //    [Description("切割")]
        //    SINGLE = 1,
        //    [Description("喷漆")]
        //    DOUBLE = 2,         
        //}

        #region  // 串口属性
        /// <summary>
        /// 端口名称
        /// </summary>
        public static string PortName
        {
            get { return iFile.GetString("PADSECTION", "PortName", "COM3"); }
        }
        /// <summary>
        /// 波特率
        /// </summary>
        public static int BaudRate
        {
            get { return iFile.GetInt("PADSECTION", "BaudRate",9600); }

        }
        /// <summary>
        /// 指定奇偶校验位
        /// </summary>
        public static Parity Paritys
        {
            get
            {
                string par = iFile.GetString("PADSECTION", "Parity","");
                switch (par)
                {
                    case "0":
                        return Parity.None;
                       // break;
                    case "1":
                        return Parity.Odd;
                       // break;
                    case "2":
                        return Parity.Even;
                       // break;
                    case "3":
                        return Parity.Mark;
                       // break;
                    default:
                        return Parity.Space;
                       // break;
                }
            }
        }
        /// <summary>
        /// 数据位值
        /// </summary>
        public static int DataBits
        {
            get { return iFile.GetInt("PADSECTION", "dataBits", 8); }
        }

        /// <summary>
        /// 使用的停止位数
        /// </summary>
        public static StopBits StopBit
        {
            get
            {
                string bit = iFile.GetString("PADSECTION", "StopBits", "");

                switch (bit)
                {
                    case "0":
                        return StopBits.None;
                        //break;
                    case "1":
                        return StopBits.One;
                       // break;
                    case "2":
                        return StopBits.Two;
                       // break;
                    default:
                        return StopBits.OnePointFive;
                       // break;
                }
            }
        }
        #endregion

        public Form1()
        {
            
            InitializeComponent();
            mac = GetMacAddress();
            padOnInfoBindingSource.DataSource = DS.PadOnInfo;
            dataGridView1.DataSource = padOnInfoBindingSource;
            padFinishInfoBindingSource.DataSource = DS.PadFinishInfo;
            dataGridView2.DataSource = padFinishInfoBindingSource;
            padReaderDataBindingSource.DataSource = DS.PadReaderData;
            dataGridView3.DataSource = padReaderDataBindingSource;

    //        dataGridView1.AutoGenerateColumns = false;
            dataGridView3.MergeColumnNames.Add("dataGridViewTextBoxColumn15");
            dataGridView3.MergeColumnNames.Add("dataGridViewTextBoxColumn16");
            dataGridView3.MergeColumnNames.Add("dataGridViewTextBoxColumn17");
            dataGridView3.MergeColumnNames.Add("dataGridViewTextBoxColumn18");
            //dataGridView3.AddSpanHeader(0, 4, "填充物");

        }


        #region /////////////////方法/////////////////////////////////////;
        //获取MAC地址 
        private string GetMacAddress()
        {
            try
            {
                string mac = "";
                ManagementClass mc = new ManagementClass("Win32_NetworkAdapterConfiguration");
                ManagementObjectCollection moc = mc.GetInstances();
                foreach (ManagementObject mo in moc)
                {
                    if ((bool)mo["IPEnabled"] == true)
                    {
                        mac = mo["MacAddress"].ToString();
                        break;
                    }
                }
                moc = null;
                mc = null;
                return mac;
            }
            catch
            {
                return "unknow";
            }
            finally
            {
            }

        }
        //读入配置文件
        private bool Init()
        {
            filestr = Globals.CGlobal.inifile;//inifile=路径+\Risun.ini
            //System.Windows.Forms.Application.StartupPath + @"\Risun.ini";
            //
            if (System.IO.File.Exists(filestr) == false)
                return false;
            iFile = new Globals.CIniIFile(filestr);
            try
            {
                strSql = @"Data Source=" + iFile.GetString("LOCALSERVER", "Server", ".") + ";Initial Catalog=SUNRISE10_CDB;" +
                    "User ID=" + iFile.GetString("LOCALSERVER", "User", "sa") + ";Password=" + iFile.GetString("LOCALSERVER", "Pwd", "");
                lid = iFile.GetString("PADSECTION", "LINE", "0");
                stid = iFile.GetString("PADSECTION", "STATION", "0");
                this.trackBar1.Value = iFile.GetInt("PADSECTION", "RefreshSec", 5);
                ShowAllScreen = iFile.GetString("PADSECTION", "ShowAllScreen", "").ToUpper();//是否全屏
                SeqKind = iFile.GetInt("PADSECTION", "SeqKind", 0);//工序类型
                SeqName = iFile.GetString("PADSECTION", "SeqName", "");//工序名称
                MaxScreenFontSize = Convert.ToSingle(iFile.GetInt("PADSECTION", "MaxScreenFontSize", 20));
                SplitterDistance = iFile.GetInt("PADSECTION", "SplitterDistance", 600);//分隔符位置
                width = iFile.GetInt("PADSECTION", "width", 800);//资料宽
                height = iFile.GetInt("PADSECTION", "height", 1000);//资料高

                DS.videoSer = iFile.GetString("PADSECTION", "videoSer", "192.168.4.253");
                DS.viedoPort = iFile.GetString("PADSECTION", "viedoPort", "8080");
            }
            catch(Exception ex){
            MessageBox.Show("配置文件出错");
                return false;
            }
            this.label7.Text = this.trackBar1.Value.ToString() + "秒";
            if (lid == "0" || stid == "0")
            {
                MessageBox.Show("配置文件中站和线是未配置",
                    "提示", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return false;
            }
            if (!DS.TestConn(strSql))
            {
                MessageBox.Show("连接数据库失败！请检查用户名、密码或网络等问题。",
                    "提示", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return false;
            }
            return true;
        }
        //生成二维码
        private Bitmap CreateCode(string ErCode)
        {
            QRCodeEncoder qrCodeEncoder = new QRCodeEncoder();
            qrCodeEncoder.QRCodeEncodeMode = QRCodeEncoder.ENCODE_MODE.BYTE;
            qrCodeEncoder.QRCodeScale = 4;//大小(值越大生成的二维码图片像素越高
            qrCodeEncoder.QRCodeVersion = 0;//版本(注意：设置为0主要是防止编码的字符串太长时发生错误)
            qrCodeEncoder.QRCodeErrorCorrect = QRCodeEncoder.ERROR_CORRECTION.M;////错误效验、错误更正(有4个等级)

            System.Drawing.Bitmap bp = qrCodeEncoder.Encode(ErCode.ToString(), Encoding.GetEncoding("GB2312"));
            //Image image = bp;
            //pictureBox1.Image = bp;
            return bp;


        }
        //初始化检测PLC
        private void CheckPLC()
        {
            try
            {
                mweight = new MITSUBISHILink(1);
                mweight.Open();
                mweight.Close();
            }
            catch { MessageBox.Show("初始化三菱PLC串口失败。"); }
            try
            {
                serialPort1 = new SerialPort(PortName,BaudRate,Paritys,DataBits,StopBit);
                serialPort1.Open();
                serialPort1.ReceivedBytesThreshold = 11;
                serialPort1.DataReceived += new System.IO.Ports.SerialDataReceivedEventHandler(spReceive_DataReceived);
            }
            catch { MessageBox.Show("启动条码扫描对象失败！"); }

        }
        //视频图片视频等
        private void PlayInit(string url, int width, int height)
        {
            width = this.width;
            height = this.height;
            System.Reflection.Assembly _assembly = System.Reflection.Assembly.GetExecutingAssembly(); ;//用Assembly加载嵌入的rdlc资源         
            StreamReader reader = new StreamReader(_assembly.GetManifestResourceStream("HKMonitor.HTMLPage.htm"));
            string htmstr = reader.ReadToEnd();
            int index = htmstr.IndexOf("<body>") + 6;
            string str = PlayClass.Play(url, width, height);
            string htmlstr = htmstr.Insert(index, str);
           // webBrowser1.DocumentText = htmlstr;
            //webBrowser1.Navigate("about: blank");
            //webBrowser1.DocumentText = htmlstr;
          // this.button2.Text = this.webBrowser1.Version.ToString();
            //webBrowser1.Document.Body.InnerHtml = PlayClass.Play(url, width, height);
            //webBrowser1.DocumentText = htmstr;
            if (webBrowser1.Document == null)
            {
                webBrowser1.Navigate("about:blank");
                while (webBrowser1.ReadyState != WebBrowserReadyState.Complete)
                {
                    Application.DoEvents();
                }
                webBrowser1.Document.Write(htmlstr);
            }
            else
            {
                webBrowser1.Document.Body.InnerHtml = str;
            }
        }
        //嵌入窗体
        private void subForm()
        {
            this.groupBox3.Visible = false;
            this.groupBox2.Visible = false;
            this.groupBox1.Visible = false;
            this.panel1.Visible = true;
            this.splitContainer1.SplitterDistance = SplitterDistance;
             sub = new ShowBund(DS, BarCode, Convert.ToInt32(lid), false);//嵌入
            sub.TopLevel = false;
            //sub.Location = new System.Drawing.Point(3, 17);
           // sub.Dock = DockStyle.Fill;//把子窗体设置为控件
            sub.FormBorderStyle = FormBorderStyle.None;
            
            // this.panel1.TopMost=
            this.panel1.Controls.Clear();
            this.panel1.Controls.Add(sub);
            sub.Dock = DockStyle.Fill;
            sub.dataGridView1.Dock = DockStyle.Fill;
            this.textBox1.Focus();
            sub.Show();
            button8.Visible = true;
        }
        private void subForm1()
        {
            this.panel2.Visible = true;
            this.splitContainer1.SplitterDistance = SplitterDistance;
            sub1 = new ShowList(DS.tLlInf);//嵌入
            sub1.TopLevel = false;
            //sub.Location = new System.Drawing.Point(3, 17);
            // sub.Dock = DockStyle.Fill;//把子窗体设置为控件
            sub1.FormBorderStyle = FormBorderStyle.None;

            // this.panel1.TopMost=
           // this.panel2.Controls.Clear();
            this.panel2.Controls.Add(sub1);
            sub1.Dock = DockStyle.Fill;
           // sub1.dataGridView1.Dock = DockStyle.Fill;
            //this.textBox1.Focus();
            sub1.Show();
            button8.Visible = true;
        }
        //全屏显示
        private void ShowAllSc()
        {
            this.TopMost = true;
            this.FormBorderStyle = FormBorderStyle.None;
            this.WindowState = FormWindowState.Maximized;

            this.groupBox3.Parent = this;

            this.splitContainer1.Visible = false;
            this.button5.Visible = false;
            this.m_mnBund.Visible = false;
            this.m_mnPlayViedo.Visible = false;
            this.m_mnShowAllScreen.Text = "正常显示";

            this.groupBox3.Dock = DockStyle.Fill;
            //this.groupBox3.Focus();
            this.dataGridView3.ReadOnly = true;
            this.dataGridView3.Font = new System.Drawing.Font("微软雅黑", MaxScreenFontSize);
        }
        //根据工艺确定权限
        private void ShowBySeqKind(Int32 seqkind)
        {
            switch (seqkind)
            {
                case 1://QG
                    break;
                case 2://PQ
                    button1.Visible = false;//shengc erweima
                    button2.Visible = false;//DY
                    button3.Visible = false;//绑定
                    button5.Visible = false;//绑定JL
                    button4.Visible = false;
                    button6.Visible = false;
                    button8.Visible = false;
                    this.m_mnBund.Visible = false;
                    this.groupBox1.Visible = this.groupBox2.Visible = this.groupBox3.Visible = false;
                    break;
                case 3://BZ
                    //this.button6.Visible = true;
                    button1.Visible = false;//shengc erweima
                    button2.Visible = false;//DY
                    button3.Visible = false;//绑定
                    button5.Visible = false;//绑定JL
                    button4.Visible = true;
                    button6.Visible = false;
                    button8.Visible = false;
                    this.m_mnBund.Visible = false;
                    this.groupBox1.Visible = this.groupBox2.Visible = this.groupBox3.Visible = false;   
                    break;
                case 88:
                   // button7.Visible = true;
                    this.button5.Visible = false;
                    this.splitContainer1.Visible = false;
                    stSeqbund st = new stSeqbund(DS);
                    st.FormBorderStyle = FormBorderStyle.None;
                    st.TopLevel = false;  
                    st.Parent = this;
                    st.Dock = DockStyle.Fill;
                    st.Show();
                    //this.Close();
                    break;
                case 90:
                     // button7.Visible = true;
                    this.button5.Visible = false;
                    this.splitContainer1.Visible = false;
                    MESConfig ms = new MESConfig(DS);
                    ms.FormBorderStyle = FormBorderStyle.None;
                    ms.TopLevel = false;
                    ms.Parent = this;
                    ms.Dock = DockStyle.Fill;
                    ms.Show();
                    //this.Close();
                    break;
                case 99: 
                    this.button5.Visible = false;
                    this.splitContainer1.Visible = false;

                    FHK_Wlbm_Image hkst = new FHK_Wlbm_Image();
                    hkst.FormBorderStyle = FormBorderStyle.None;
                    hkst.TopLevel = false;
                    hkst.Parent = this;
                    hkst.Dock = DockStyle.Fill;
                    hkst.Show();
                    //this.Close();
                    break;
            }
        }

        public  byte[] ImageToBytes(Bitmap image)
        {
            MemoryStream   ms   =   new   MemoryStream(); 
            image.Save(ms,System.Drawing.Imaging.ImageFormat.Bmp); 
            byte[]   bytes=   ms.GetBuffer();  //byte[]   bytes=   ms.ToArray(); 这两句都可以，至于区别么，下面有解释
            ms.Close(); 
            return bytes;
            //ImageFormat format = image.RawFormat;
            //using (MemoryStream ms = new MemoryStream())
            //{
            //    if (format.Equals(ImageFormat.Jpeg))
            //    {
            //        image.Save(ms, ImageFormat.Jpeg);
            //    }
            //    else if (format.Equals(ImageFormat.Png))
            //    {
            //        image.Save(ms, ImageFormat.Png);
            //    }
            //    else if (format.Equals(ImageFormat.Bmp))
            //    {
            //        image.Save(ms, ImageFormat.Bmp);
            //    }
            //    else if (format.Equals(ImageFormat.Gif))
            //    {
            //        image.Save(ms, ImageFormat.Gif);
            //    }
            //    else if (format.Equals(ImageFormat.Icon))
            //    {
            //        image.Save(ms, ImageFormat.Icon);
            //    }
            //    byte[] buffer = new byte[ms.Length];
            //    //Image.Save()会改变MemoryStream的Position，需要重新Seek到Begin
            //    ms.Seek(0, SeekOrigin.Begin);
            //    ms.Read(buffer, 0, buffer.Length);
            //    return buffer;
            
        }

        #endregion

        #region /////////////////事件/////////////////////////////////////;
        private void Form1_Load(object sender, EventArgs e)
        {
            label2.Text = "MAC：" + mac;
            if (!Init())
            {
                System.Environment.Exit(0);
            }
            label3.Text = lid + "-" + stid;
            label5.Visible = false;
            DS.SetConnectStr(strSql);

            if (DS.PadLoginInfo(Convert.ToInt32(lid), Convert.ToInt32(stid), mac, 1) == 2)
            {
                MessageBox.Show("配置文件中站号线号有重复",
                         "提示", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            //if (DS.PadLoginInfo(Convert.ToInt32(lid), Convert.ToInt32(stid), mac, 0) == 1)
            //{
            //    //只有当前线开机
            //    DS.GetPadOnInfo(-1);//获取全部
            //    DS.GetPadFinishInfo(-1);
            //    DS.GetPadReaderData();
            //}
            else
            {
                DS.GetChanges();
                timer1_Tick(null,null);
                //DS.GetPadOnInfo(Convert.ToInt32(lid));//获取分配给其的
            }
            this.timer1.Interval = this.trackBar1.Value * 1000;
            timer1.Enabled = true;
            if (ShowAllScreen == "ON")
            {
                ShowAllSc();
            }
            else
            {
                ShowBySeqKind(SeqKind);
            }
        }
        private void Form1_FormClosing(object sender, FormClosingEventArgs e)
        {
            DS.SetConnectStr(strSql);
            //登出当前机器
            DS.PadLoginInfo(Convert.ToInt32(lid), Convert.ToInt32(stid), GetMacAddress(), -1);
        }
        //扫码枪读数
        protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
        {
            System.Text.RegularExpressions.Regex rex = new System.Text.RegularExpressions.Regex(@"^\d+$");
            if (SeqKind == 1 || SeqKind == 4)
            {//切割
                textBox1.Focus();
                textBox1.Text += ((char)keyData).ToString();
                if (keyData == Keys.Enter)
                {
                    BarCode = textBox1.Text.Trim();
                    if (!rex.IsMatch(BarCode))
                    {
                       // MessageBox.Show("条码错误");
                        lbMsg.Text = "条码错误";
                        lbMsg.ForeColor = Color.Red;
                        //lbMsg.Visible = true;
                        BarCode = "";
                        textBox1.Text = String.Empty;
                        return false;
                    }
                    lbMsg.Text = "";
                    textBox1.Text = String.Empty;
                    label5.Visible = true;                   
                    return true;
                }
            }
            else if (SeqKind == 2)
            { //喷漆    果胶         
                try
                {
                    textBox1.Focus();
                    textBox1.Text += ((char)keyData).ToString();
                    if (keyData == Keys.Enter)
                    {
                        BarCode = textBox1.Text.Trim();
                        if (!rex.IsMatch(BarCode))
                        {
                            //MessageBox.Show("条码错误");
                            lbMsg.Text = "条码错误";
                            lbMsg.ForeColor = Color.Red;
                            BarCode = "";
                            textBox1.Text = String.Empty;
                            return false;
                        }
                        textBox1.Text = String.Empty;
                        subForm();
                        button4_Click(null, null);
                        button4.Visible = true;
                        if (!DS.SetDateTime(BarCode))
                        {
                           // MessageBox.Show("重建");
                            lbMsg.Text = "重刷一次条码";
                            lbMsg.ForeColor = Color.Red;
                        }
                        lbMsg.Text = "";
                        return true;
                    }
                }
                catch { }          
            }
            else if (SeqKind ==3)
            {
                textBox1.Focus();
                textBox1.Text += ((char)keyData).ToString();
                if (keyData == Keys.Enter)
                {
                    BarCode = textBox1.Text.Trim();
                    if (!rex.IsMatch(BarCode))
                    {
                        //MessageBox.Show("条码错误");
                        lbMsg.Text = "条码错误";
                        lbMsg.ForeColor = Color.Red;
                        BarCode = "";
                        textBox1.Text = String.Empty;
                        return false;
                    }
                    textBox1.Text = String.Empty;
                    subForm();
                    button4_Click(null,null);
                    button6.Visible = true;
                    button6_Click(null,null);
                    return true;
                }
            }

            return base.ProcessCmdKey(ref msg, keyData);
        }
        //生成
        private void button1_Click(object sender, EventArgs e)
        {
            CreateCode("aa");
            Print pt = new Print(pictureBox1.Image);
            pt.Show();


        }
        //打印
        private void button2_Click(object sender, EventArgs e)
        {
            PrintDialog MyPrintDg = new PrintDialog();
            MyPrintDg.Document = printDocument1;
            if (MyPrintDg.ShowDialog() == DialogResult.OK)
            {
                try
                {
                    printDocument1.Print();
                }
                catch
                {   //停止打印
                    printDocument1.PrintController.OnEndPrint(printDocument1, new System.Drawing.Printing.PrintEventArgs());
                }
            }
        }

        private void printDocument1_PrintPage(object sender, System.Drawing.Printing.PrintPageEventArgs e)
        {
            e.Graphics.DrawImage(pictureBox1.Image, 20, 20);
            e.HasMorePages = false;
        }

        private void timer1_Tick(object sender, EventArgs e)
        {
            if (label5.Visible == false)
            {
                Int32 index=0 ;
                if (dataGridView3.SelectedRows.Count > 0)
                    index = dataGridView3.SelectedRows[0].Index;//选中的第一条索引
                if (SeqKind == 1)
                {
                    timer1.Enabled = false;
                    //刷新需要准备的
                    DS.GetPadOnInfo(-1);//获取全部
                    DS.GetPadFinishInfo(-1);
                    DS.GetPadReaderData(-1);
                    dataGridView3.ClearSelection();
                    dataGridView3.Rows[index].Selected = true;
                    timer1.Enabled = true;
                }
                else 
                {
                    timer1.Enabled = false;
                    //刷新需要准备的
                    DS.GetPadOnInfo(Convert.ToInt32(lid));
                    DS.GetPadFinishInfo(Convert.ToInt32(lid));
                    DS.GetPadReaderData(Convert.ToInt32(lid));
                    dataGridView3.ClearSelection();
                    dataGridView3.Rows[index].Selected = true;
                    timer1.Enabled = true;
                }
            }
            else {
                timer1.Enabled = true;
            }
            
        }
        //串口接收事件
        public void spReceive_DataReceived(object sender, System.IO.Ports.SerialDataReceivedEventArgs e)
        {
            sReceiveDatatemp = serialPort1.ReadExisting();
        }
        //滑块
        private void trackBar1_Scroll(object sender, EventArgs e)
        {
            this.label7.Text = this.trackBar1.Value.ToString() + "秒";
            this.timer1.Enabled = false;
            this.timer1.Interval = this.trackBar1.Value *1000;
            this.timer1.Enabled= true;
            //保存
            iFile.WriteString("PADSECTION", "RefreshSec", this.trackBar1.Value.ToString());
        }
        //准备绑定的右键菜单
        private void dataGridView3_CellMouseDown(object sender, DataGridViewCellMouseEventArgs e)
        {
            if (e.Button == MouseButtons.Right)
            {
                if (e.RowIndex >= 0)
                {
                    //若行已是选中状态就不再进行设置
                    if (dataGridView3.Rows[e.RowIndex].Selected == false)
                    {
                        dataGridView3.ClearSelection();
                        dataGridView3.Rows[e.RowIndex].Selected = true;
                    }
                    //只选中一行时设置活动单元格
                    if (dataGridView3.SelectedRows.Count == 1)
                    {
                        dataGridView3.CurrentCell = dataGridView3.Rows[e.RowIndex].Cells[e.ColumnIndex];
                    }
                    //弹出操作菜单
                    
                    contextMenuStrip1.Show(MousePosition.X, MousePosition.Y);
                }
              
            }
            //else if (e.Button == MouseButtons.Left)
            //{
            //    if (e.RowIndex >= 0)
            //    {
            //        //若行已是选中状态就不再进行设置
            //        if (dataGridView3.Rows[e.RowIndex].Selected == false)
            //        {
            //            dataGridView3.ClearSelection();
            //            //设置选中一组
            //            foreach (DataGridViewRow row in dataGridView3.Rows)
            //            {
            //                if (row.Cells["ID"].Value.ToString().Trim() == dataGridView3.Rows[e.RowIndex].Cells["ID"].Value.ToString().Trim())
            //                    dataGridView3.Rows[row.Index].Selected = true;
            //            }
            //            dataGridView3.Rows[e.RowIndex].Selected = true;
            //        }
            //    }
            //}
        }
        //右键菜单
        private void contextMenuStrip1_Click(object sender, EventArgs e)
        {
            contextMenuStrip1.Close();
            ToolStripItem mnItem = contextMenuStrip1.GetItemAt((e as MouseEventArgs).Location);
            if (mnItem == null)
                return;
            switch (mnItem.Name)
            {
                case "m_mnBund":
                    try
                    {
                        if (dataGridView3.SelectedRows.Count > 0)
                        {
                            DataSet1.PadReaderDataRow ReaderRow = (dataGridView3.SelectedRows[0].DataBoundItem as DataRowView).Row as DataSet1.PadReaderDataRow;
                            if (SeqKind == 1)
                            {
                                if (DS.SaveBundInfo(ReaderRow.guid, BarCode, ReaderRow.ST_KIND) == true)
                                {
                                    MessageBox.Show(" 绑定成功");
                                    label5.Visible = false;
                                    DS.GetPadReaderData(-1);
                                }
                            }
                            else if (SeqKind == 4)
                            {
                                if ( DS.SaveBundInfo(ReaderRow.guid, BarCode, ReaderRow.ST_KIND) && DS.SetDateTime(BarCode))
                                {
                                    MessageBox.Show(" 绑定成功");
                                    label5.Visible = false;
                                    DS.GetPadReaderData(Convert.ToInt32(lid));
                                }
                            }
                        }
                        else
                        {
                            MessageBox.Show("请选择要绑定的芯");
                        }
                    }
                    catch (Exception ex)
                    { MessageBox.Show("绑定ERROR:" + ex.ToString()); }
                    break;
                case "m_mnPlayViedo":
                    if (dataGridView3.SelectedRows.Count > 0)
                    {
                        DataSet1.PadReaderDataRow ReaderRow = (dataGridView3.SelectedRows[0].DataBoundItem as DataRowView).Row as DataSet1.PadReaderDataRow;
                        PlayInit(DS.GetViedoUrl(ReaderRow.ParMono,SeqName), 800, 670);
                    }
                    else
                    {
                        MessageBox.Show("请选择需要查看哪个工单的工艺资料");
                    }
                    
                    break;
                case "m_mnShowAllScreen":
                    if (this.WindowState != FormWindowState.Maximized)
                    {
                        this.TopMost = true;
                        this.FormBorderStyle = FormBorderStyle.None;
                        this.WindowState = FormWindowState.Maximized;

                        this.groupBox3.Parent = this;

                        this.splitContainer1.Visible = false;
                        this.button5.Visible = false;
                        this.m_mnBund.Visible = false;
                        this.m_mnPlayViedo.Visible = false;
                        this.m_mnShowAllScreen.Text = "正常显示";

                        this.groupBox3.Dock = DockStyle.Fill;
                        this.dataGridView3.Font = new System.Drawing.Font("微软雅黑", 20F);

                        break;
                    }
                    else
                    {
                        this.FormBorderStyle = FormBorderStyle.FixedSingle;
                        this.WindowState = FormWindowState.Normal;

                        this.groupBox3.Parent = this.splitContainer1.Panel1;
                        this.splitContainer1.Visible = true;
                        this.button5.Visible = true;
                        this.m_mnBund.Visible = true;
                        this.m_mnPlayViedo.Visible = true;

                        this.m_mnShowAllScreen.Text = "全屏显示";

                        this.groupBox3.Dock = DockStyle.None;
                        this.dataGridView3.Font = new System.Drawing.Font("宋体", 12F);

                        break;
                    }
            }

        }


        //绑定
        private void button3_Click(object sender, EventArgs e)
        {
            try
            {
                
                if (dataGridView3.SelectedRows.Count > 0)
                {
                    DataSet1.PadReaderDataRow ReaderRow = (dataGridView3.SelectedRows[0].DataBoundItem as DataRowView).Row as DataSet1.PadReaderDataRow;
                    Int32 index = dataGridView3.SelectedRows[0].Index;//选中的第一条索引
                    if (BarCode.Length>1 &&DS.isBarCodeExist(BarCode) == 0)
                    {
                        if (SeqKind == 1)
                        {
                            if (DS.SaveBundInfo(ReaderRow.guid, BarCode, ReaderRow.ST_KIND) == true)
                            {
                                // MessageBox.Show(" 绑定成功");
                                lbMsg.Text = "绑定成功";
                                lbMsg.ForeColor = Color.Green;
                                label5.Visible = false;
                                DS.GetPadReaderData(-1);
                                dataGridView3.ClearSelection();
                                dataGridView3.Rows[index].Selected = true;
                            }
                        }
                        else if (SeqKind == 4)
                        {
                            if (DS.SaveBundInfo(ReaderRow.guid, BarCode, ReaderRow.ST_KIND) && DS.SetDateTime(BarCode))
                            {
                                // MessageBox.Show(" 绑定成功");
                                lbMsg.Text = "绑定成功";
                                lbMsg.ForeColor = Color.Green;
                                label5.Visible = false;
                                DS.GetPadReaderData(Convert.ToInt32(lid));
                                dataGridView3.ClearSelection();
                                dataGridView3.Rows[index].Selected = true;
                            }
                        }
                    }
                    else {
                        lbMsg.Text = "条码无效或条码重复";
                        lbMsg.ForeColor = Color.Red;
                    }
                }
                else
                {
                   // MessageBox.Show("请选择要绑定的芯");
                    lbMsg.Text = "请选择要绑定的芯!!";
                    lbMsg.ForeColor = Color.Red;
                }
            }
            catch (Exception ex)
            { MessageBox.Show("绑定ERROR:"+ex.ToString()); }
            //break;
        }
        //查看工艺视频
        private void button4_Click(object sender, EventArgs e)
        {
            this.panel2.Visible = false;
            if (SeqKind == 1 || SeqKind == 4)
            {
                if (dataGridView3.SelectedRows.Count > 0)
                {
                    DataSet1.PadReaderDataRow ReaderRow = (dataGridView3.SelectedRows[0].DataBoundItem as DataRowView).Row as DataSet1.PadReaderDataRow;
                    PlayInit(DS.GetViedoUrl(ReaderRow.ParMono, SeqName), 800, 670);
                }
                else
                {
                    MessageBox.Show("请选择需要查看哪个工单的工艺资料");
                }
            }
            else if (SeqKind == 2||SeqKind == 3)
            {
                if (sub.dataGridView1.SelectedRows.Count > 0)
                {
                    DataSet1.tBundPartRow ReaderRow = (sub.dataGridView1.SelectedRows[0].DataBoundItem as DataRowView).Row as DataSet1.tBundPartRow;
                    PlayInit(DS.GetViedoUrl(ReaderRow.Mono, SeqName), 800, 670);                   
                }
                else
                {
                    MessageBox.Show("请选择需要查看哪个工单的工艺资料");
                }
            }

        }
        //查看或修改
        private void button5_Click(object sender, EventArgs e)
        {
            new ShowBund(DS, BarCode, Convert.ToInt32(lid), true).Show();            
        }
        //物流清单打印
        private void button6_Click(object sender, EventArgs e)
        {
           //DS.Gettlogistics("1234566");
            //new Print1(DS).Show();
            Print1 pt = new Print1();
            DS.Gettlogistics(BarCode);
            DataTable dt = DS.tlogistics;
            foreach (DataRow row in dt.Rows)
            {
                ErCode = "http://www.hkfoam.com/?ID=" + row["Mono"].ToString();
               // CreateCode(ErCode);
               // Image img = this.pictureBox1.Image;
                byte[] bytes = ImageToBytes(CreateCode(ErCode));
                //BinaryFormatter binFormatter = new BinaryFormatter();
                //MemoryStream memStream = new MemoryStream();
                //binFormatter.Serialize(memStream, img);
                //byte[] bytes = memStream.GetBuffer();
                //string base64 = Convert.ToBase64String(bytes);

                //FileStream fs = new FileStream();
                //byte[] buff = new byte[fs.Length];
                //fs.Read(buff, 0, buff.Length);
                //fs.Close();
                row["img"] = bytes;
            } 
            CrystalReport1 cr1 = new CrystalReport1();
            cr1.SetDataSource(dt);           
            //cr1.Refresh();
            //pt.crystalReportViewer1.ReportSource = cr1;
            //pt.Show();
            cr1.PrintToPrinter(1, true, 1, 1);
        }

        #endregion

        private void button7_Click(object sender, EventArgs e)
        {
            new stSeqbund(DS).Show();
        }
        //领料清单：
        private void button8_Click(object sender, EventArgs e)
        {
            if (SeqKind == 1 || SeqKind == 4)
            {
                if (dataGridView3.SelectedRows.Count > 0)
                {
                    DataSet1.PadReaderDataRow ReaderRow = (dataGridView3.SelectedRows[0].DataBoundItem as DataRowView).Row as DataSet1.PadReaderDataRow;
                    DS.GettLlInf(ReaderRow.ParMono, SeqName);
                    subForm1();
                }
                else
                {
                    MessageBox.Show("请选择需要查看哪个订单的领料信息");
                }
            }
            else if (SeqKind == 2 || SeqKind == 3)
            {
                if (sub.dataGridView1.SelectedRows.Count > 0)
                {
                    DataSet1.tBundPartRow ReaderRow = (sub.dataGridView1.SelectedRows[0].DataBoundItem as DataRowView).Row as DataSet1.tBundPartRow;
                    DS.GettLlInf(ReaderRow.Mono, SeqName);
                    subForm1();
                }
                else
                {
                    MessageBox.Show("请选择需要查看哪个订单的领料信息");
                }
            }
        }



    }
}
