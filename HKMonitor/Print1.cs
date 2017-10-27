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
    public partial class Print1 : Form
    {
        public Print1()
        {
            InitializeComponent();
            //CrystalReport1 cr1 = new CrystalReport1();
            //cr1.SetDataSource(ds);
            //crystalReportViewer1.ReportSource = cr1;
        }

        private void Print1_Load(object sender, EventArgs e)
        {

            //this.reportViewer1.RefreshReport();
        }

        private void crystalReportViewer1_Load(object sender, EventArgs e)
        {

        }
    }
}
