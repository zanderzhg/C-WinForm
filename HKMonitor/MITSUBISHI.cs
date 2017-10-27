using System;
using System.Collections.Generic;
using System.Text;
using ACTMULTILib;
using ACTSUPPORTLib;

namespace HKMonitor
{
    public delegate void IconRead(bool Readed);
    public delegate void LinkError(object sender, string errorMessage);
    interface ILink
    {
        int Open();
        int Close();
        int ReadDeviceBlock(string sDevice, int iSize, out int[] iData);
        int ReadDeviceString(string sDevice, int iSize, out string sData);
        int SetDevice(string sDevice, int iData);
        int GetDevice(string sDevice, out int iData);
        int WriteDeviceBlock(string sDevice, int iSize, ref int[] iData);
        int WriteDeviceString(string sDevice, int iSize, string sData);
    }

    public abstract class LinkBase : ILink
    {
        public delegate void LinkError(object sender, string errorMessage);
        private string last_message = string.Empty;
        public event LinkError OnErrorMessageOccur;
        protected void OnErrorMessage(string errorMessage)
        {
            if (OnErrorMessageOccur != null && last_message != errorMessage)
            {
                last_message = errorMessage;
                OnErrorMessageOccur.Invoke(this, errorMessage);
            }
        }
        protected bool mvarIsOpen = false;
        abstract public bool IsOpen { get; }
        abstract public int Open();
        abstract public int Close();
        abstract public int ReadDeviceBlock(string sDevice, int iSize, out int[] iData);
        abstract public int ReadDeviceString(string sDevice, int iSize, out string sData);
        abstract public int SetDevice(string sDevice, int iData);
        abstract public int GetDevice(string sDevice, out int iData);
        abstract public int WriteDeviceBlock(string sDevice, int iSize, ref int[] iData);
        abstract public int WriteDeviceString(string sDevice, int iSize, string sData);
    }
    public class MITSUBISHILink : LinkBase
    {
        private ActEasyIFClass mvarActEasyIF;
        private ActSupportClass mvarActSupport;
        private void OnErrorMessage(int errorCode)
        {
            string errorMessage = "";
            mvarActSupport.GetErrorMessage(errorCode, out errorMessage);
            OnErrorMessage(errorMessage);
        }

        private int mvarErrorCode;
        private int ErrorCode
        {
            get
            {
                return mvarErrorCode;
            }
            set
            {
                mvarErrorCode = value;
                if (value != 0)
                {
                    OnErrorMessage(mvarErrorCode);
                }
            }
        }

        public override int Open()
        {
#if (NoCom)
            mvarIsOpen = true;
            ErrorCode = 0;
#else
            lock (mvarActEasyIF)
            {
                mvarIsOpen = (ErrorCode = mvarActEasyIF.Open()) == 0 ? true : false;
            }
#endif
            return ErrorCode;
        }

        public override int Close()
        {
#if (NoCom)
            mvarIsOpen = false;
            ErrorCode = 0;
#else
            lock (mvarActEasyIF)
            {
                mvarIsOpen = (ErrorCode = mvarActEasyIF.Close()) == 0 ? false : true;
            }
#endif
            return ErrorCode;
        }

        //private bool mvarIsOpen = false;
        public override bool IsOpen
        {
            get
            {
                return mvarIsOpen;
            }
        }
        private static Dictionary<string, int> NoComDataSet = new Dictionary<string, int>();
        public static void GetHeadAndNumber(string sDevice, out string head, out int number)
        {
            head = "";
            int count = 0;
            do
            {
                head += sDevice.Substring(count, 1);
                count++;
            }
            while (!Char.IsNumber(sDevice, count));
            number = Convert.ToInt32(sDevice.Substring(count));
        }

        private static int NoComReadDeviceBuffer(string sDevice, int iSize, out int[] iData)
        {
            iData = new int[iSize];
            string keyHead = "";
            int number = 0;
            GetHeadAndNumber(sDevice, out keyHead, out number);
            Random random = new Random();
            for (int i = 0; i < iSize; i++)
            {
                string key = keyHead + (number + i);
                if (!NoComDataSet.ContainsKey(key))
                    NoComDataSet.Add(key, random.Next(Int16.MaxValue));
                iData[i] = NoComDataSet[key];
            }
            return 0;
        }
        private static int NoComWriteDeviceBuffer(string sDevice, int iSize, ref int[] iData)
        {
            string keyHead = "";
            int number = 0;
            GetHeadAndNumber(sDevice, out keyHead, out number);
            Random random = new Random();
            for (int i = 0; i < iSize; i++)
            {
                string key = keyHead + (number + i);
                if (!NoComDataSet.ContainsKey(key))
                    NoComDataSet.Add(key, random.Next(Int16.MaxValue));
                NoComDataSet[key] = iData[i];
            }
            return 0;
        }


        public override int ReadDeviceBlock(string sDevice, int iSize, out int[] iData)
        {
            iData = new int[iSize];
#if (NoCom)
            ErrorCode = NoComReadDeviceBuffer(sDevice, iSize, out iData);
#else
            lock (mvarActEasyIF)
            {
                int retry = 0;
                do
                {
                    ErrorCode = mvarActEasyIF.ReadDeviceBlock(sDevice, iSize, out iData[0]);
                    if (ErrorCode != 0)
                        System.Threading.Thread.Sleep(100);
                    retry++;
                } while (ErrorCode != 0 && retry < 3);
            }
#endif
            return ErrorCode;
        }

        public override int ReadDeviceString(string sDevice, int iSize, out string sData)
        {
            int result = 0;
            sData = "";
            int[] iData = new int[iSize];
            if ((result = ReadDeviceBlock(sDevice, iSize, out iData)) != 0)
            {
                return result;
            }
            else
            {
                StringBuilder sb = new StringBuilder();
                for (int i = 0; i < iData.Length; i++)
                {
                    sb.Append(MITSUBISHILink.IntToASCIIString(iData[i]));
                }
                sData = sb.ToString();
            }
            return result;
        }

        public override int SetDevice(string sDevice, int iData)
        {
#if (NoCom)
            int[] iDatas = new int[] { iData };
            ErrorCode = NoComWriteDeviceBuffer(sDevice, 1, ref iDatas);
#else
            lock (mvarActEasyIF)
            {
                int retry = 0;
                do
                {
                    ErrorCode = mvarActEasyIF.SetDevice(sDevice, iData);
                    if (ErrorCode != 0)
                        System.Threading.Thread.Sleep(100);
                    retry++;
                } while (ErrorCode != 0 && retry < 3);
            }
#endif
            return ErrorCode;
        }

        public override int GetDevice(string sDevice, out int iData)
        {
            iData = 0;
#if (NoCom)
            int[] iDatas = new int[] { iData };
            ErrorCode = NoComWriteDeviceBuffer(sDevice, 1, ref iDatas);
#else
            lock (mvarActEasyIF)
            {
                int retry = 0;
                do
                {
                    ErrorCode = mvarActEasyIF.GetDevice(sDevice, out iData);
                    if (ErrorCode != 0)
                        System.Threading.Thread.Sleep(100);
                    retry++;
                } while (ErrorCode != 0 && retry < 3);
            }
#endif
            return ErrorCode;
        }

        public override int WriteDeviceBlock(string sDevice, int iSize, ref int[] iData)
        {
#if (NoCom)
            ErrorCode = NoComWriteDeviceBuffer(sDevice, iSize, ref iData);
#else
            lock (mvarActEasyIF)
            {
                int retry = 0;
                do
                {
                    ErrorCode = mvarActEasyIF.WriteDeviceBlock(sDevice, iSize, ref iData[0]);
                    if (ErrorCode != 0)
                        System.Threading.Thread.Sleep(100);
                    retry++;
                } while (ErrorCode != 0 && retry < 3);
            }
#endif
            return ErrorCode;
        }

        public override int WriteDeviceString(string sDevice, int iSize, string sData)
        {
            sData = sData.PadRight(iSize * 2, '\0');
            int[] iData = new int[iSize];
            for (int i = 0; i < iData.Length; i++)
            {
                iData[i] = MITSUBISHILink.ASCIIStringToInt(sData.Substring((i * 2), 2));
            }
            return WriteDeviceBlock(sDevice, iSize, ref iData);
        }

        public static string IntToASCIIString(int iValue)
        {
            string result = "";
            int formater = 0x000000FF;
            Byte[] destByte = new Byte[] { (Byte)(iValue & formater), (Byte)((iValue >> 8) & formater) };
            ASCIIEncoding ascii = new ASCIIEncoding();
            Char[] chars = new Char[2];
            ascii.GetChars(destByte, 0, 2, chars, 0);
            result = chars[0].ToString() + chars[1].ToString();
            return result;
        }

        public static int ASCIIStringToInt(String sValue)
        {
            int result = 0;
            Char[] chars = new Char[2];
            sValue.CopyTo(0, chars, 0, 2);
            ASCIIEncoding ascii = new ASCIIEncoding();
            Byte[] destByte = new Byte[2];
            ascii.GetBytes(chars, 0, 2, destByte, 0);
            result = destByte[0] | (destByte[1] << 8);
            return result;
        }

        public MITSUBISHILink(int actLogicalStationNumber)
        {
            mvarActEasyIF = new ActEasyIFClass();
            mvarActEasyIF.ActLogicalStationNumber = actLogicalStationNumber;
            mvarActSupport = new ActSupportClass();
        }
    }
}
