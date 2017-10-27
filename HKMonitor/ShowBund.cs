using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;

namespace HKMonitor
{
    public partial class ShowBund : Form
    {
        private DataSet1 m_dst ;
        private bool m_canEdit = false;
        private string BarCode;
        private Int32 lid = 0;
        public ShowBund(DataSet1 m_dst, string BarCode, Int32 lid,bool flag)
        {
            InitializeComponent();
            tBundPartBindingSource.DataSource = m_dst.tBundPart;
            tBundPartBindingSource.Sort = "BarCode";

            dataGridView1.AutoGenerateColumns = false;
            dataGridView1.DataSource = tBundPartBindingSource;
            dataGridView1.MergeColumnNames.Add("barCodeDataGridViewTextBoxColumn");
            //dataGridView1.MergeColumnNames.Add("partNoDataGridViewTextBoxColumn");
            //dataGridView1.MergeColumnNames.Add("monoDataGridViewTextBoxColumn");
            this.lid = lid;
            this.BarCode = BarCode;
            this.m_dst = m_dst;
            if (!flag)
            {
                toolStrip1.Visible = false;
                dataGridView1.ReadOnly = true;
            }

        }
        public bool CanEdit
        {
            get
            {
                return m_canEdit;
            }

            set
            {
                m_canEdit = value;
                EnableBtn(!value);
                foreach (DataGridViewColumn col in dataGridView1.Columns)
                {
                   col.ReadOnly = !m_canEdit;                 
                }
                dataGridView1.Refresh();
            }
        }
        public void EnableBtn(bool viewMode)
        {
            toolStripButton1.Enabled = !viewMode;
            toolStripButton2.Enabled = !viewMode;
            toolStripButton3.Enabled = viewMode;
            toolStripButton4.Enabled = viewMode;
        }
        //刷新
        private void toolStripButton3_Click(object sender, EventArgs e)
        {
            m_dst.GettBundPart(lid);
            tBundPartBindingSource.Filter = "1=1";
        }
        //保存
        private void toolStripButton1_Click(object sender, EventArgs e)
        {
            Cursor = Cursors.WaitCursor;
            dataGridView1.EndEdit();
            tBundPartBindingSource.EndEdit();
            try
            {
                DataSet1.tBundPartRow BundRow = (dataGridView1.SelectedRows[0].DataBoundItem as DataRowView).Row as DataSet1.tBundPartRow;
                string msg= m_dst.EditBundInfo(BundRow.partNo, BundRow.BarCode, lid);
                if (msg != "")
                {
                    MessageBox.Show(msg);
                }
            }
            catch { MessageBox.Show("修改失败"); }
            
            CanEdit = false;
            Cursor = Cursors.Default;
            m_dst.GettBundPart(lid);
        }
        //取消
        private void toolStripButton2_Click(object sender, EventArgs e)
        {
            if (m_dst.tBundPart.Select(null, null, DataViewRowState.ModifiedCurrent).Length > 0)
            {
                DialogResult rlt = MessageBox.Show(Globals.CLanguage.GetString("确定要取消修改吗？"),
                    Globals.CLanguage.GetString("提示"),
                        MessageBoxButtons.OKCancel, MessageBoxIcon.Question, MessageBoxDefaultButton.Button2);
                if (rlt != DialogResult.OK)
                    return;
            }
            CanEdit = false;
        }
        //编辑
        private void toolStripButton4_Click(object sender, EventArgs e)
        {
            CanEdit = true;
        }
        //绑定号变化
        private void toolStripTextBox1_TextChanged(object sender, EventArgs e)
        {
            string filter = "1=1 ";
            string str = toolStripTextBox1.Text;

            if (!string.IsNullOrEmpty(str))
            {
                filter += string.Format(" AND BarCode like '%{0}%'", str);
            }
            tBundPartBindingSource.Filter = filter;
        }
        
        private void ShowBund_Load(object sender, EventArgs e)
        {
            m_dst.GettBundPart(lid);
            string filter = "1=1 ";
            if (!string.IsNullOrEmpty(BarCode))
            {
                filter += string.Format(" AND BarCode = '{0}'", BarCode);
            }
            tBundPartBindingSource.Filter = filter;
        }
    }
}
