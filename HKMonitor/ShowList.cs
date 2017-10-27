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
    public partial class ShowList : Form
    {
        public ShowList(DataSet1.tLlInfDataTable m_dst)
        {
            InitializeComponent();

            tLlInfBindingSource.DataSource = m_dst;
            tLlInfBindingSource.Sort = "wName";
            dataGridView1.DataSource = tLlInfBindingSource;
        }
    }
}
