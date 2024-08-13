package it.innove;

import android.util.Log;
import android.widget.TextView;

//import com.github.psambit9791.jdsp.filter.Butterworth;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.Arrays;

public class DataParsingAndProcessing {

    public ArrayList<double[]> lol_valuesR = new ArrayList<double[]>();
    public ArrayList<double[]> lol_valuesIR = new ArrayList<double[]>();
    public ArrayList<Double> list_time = new ArrayList<Double>();
    public ArrayList<Double> list_stimulus = new ArrayList<Double>();

    // Initialize the channel-wise values
    int numChannels = 40;
    double[] channelValuesR = new double[numChannels];
    double[] channelValuesIR = new double[numChannels];
    double[] channelValuesDC = new double[16];

    double[] channelWiseSNR_R = new double[numChannels];
    double[] channelWiseSNR_IR = new double[numChannels];
    double[] allDeviceData;

    int[] ledIntensityValues = {
            8, 8, 8, 8, // regular power sources
            8, 8, 8, 8,
            8, 8, 8, 8,
            8, 8, 8, 8,
            8, 8, 8, 8, // low power sources
            8, 8, 8, 8,
            8, 8, 8, 8,
            8, 8, 8, 8}; // regular power sources

    double[] darkCurrentMeasurements;
    int bufferSize= 100;
    double relativeTimeStamp = 0;
    double stimulusValue = 0;
    double[] time = new double[bufferSize];
    double[] curr740nm = new double[bufferSize];
    double[] curr850nm = new double[bufferSize];
    double[] currStimulus = new double[bufferSize];

    public int currentDataBufferSize = 0;

    boolean isDataSet1Ready = false;
    boolean isDataSet2Ready = false;
    boolean isDataSet3Ready = false;
    boolean isDataSet4Ready = false;

    boolean isDataReady = false;

    int count740 = 0;
    int count850 = 0;
    int countDC = 0;

    double sqi_thrUp_intensity = 2f; // set empirically
    double sqi_thrLow_intensity = -5f; // set empirically
    double sqi_thr_sumHbratio = 0.5f; // set empirically

    boolean sufficientDataCollected = false;
    double[][] dataArray;

    int durationDataRound = 0;
    float durationDataRoundSeconds = 0;

    int batteryPercentage;

    int numSources = 33; // 16 RP, 16 LP, 1 DC
    int numDetectors = 16;
    int numDataPointsPerSource= 17; // 16 detectors, 1 timestamp
    int numBytesPerValue = 4;

    byte[] receivedDataArray = new byte[numSources * numDataPointsPerSource * numBytesPerValue];
    float lastTimeStamp = 0;

    public DataParsingAndProcessing(
            double sqi_thrUp_intensity,
            double sqi_thrLow_intensity,
            double sqi_thr_sumHbratio,
            int[] ledIntensityValues){

        // Get SQI parameters
        this.sqi_thr_sumHbratio = sqi_thr_sumHbratio;
        this.sqi_thrLow_intensity = sqi_thrLow_intensity;
        this.sqi_thrUp_intensity = sqi_thrUp_intensity;
        this.ledIntensityValues = ledIntensityValues;

        dataArray = new double[numSources][numDetectors]; // subtract one to re
        darkCurrentMeasurements = new double[16];

    }

    public CustomDataBundle convertByteToChannelData(ByteBuffer wrap){

        wrap.order(ByteOrder.LITTLE_ENDIAN);

        Log.e("ReceivedBLEData", String.valueOf(wrap.capacity()));

        if (wrap.capacity() == 289){ // battery level + LED intensities
            // Get battery percentage
            Log.e("DataReceived",  "Battery level information: " + String.valueOf(wrap.capacity()));
            batteryPercentage = wrap.getInt(0);

            // Get LED intensities
            for (int i = 1; i < 32; i++){
                ledIntensityValues[i-1] = wrap.getInt((i-1)*4);
            }

        }
        else if (wrap.capacity() == 480){
            Log.e("DataReceived",  "Battery level information: " + String.valueOf(wrap.capacity()));
            // Get data set number
            int currDataSet = wrap.getInt(0);

            if (currDataSet == 1){
                Log.e("Parsing", "Data Set 1" + ", " + String.valueOf(wrap.capacity()));
                transferToReceivedDataArray(0, wrap);
                isDataReady = false;
                isDataSet1Ready = true;
            }
            else if(currDataSet == 2){
                Log.e("Parsing", "Data Set 2" + ", " + String.valueOf(wrap.capacity()));
//                transferToReceivedDataArray(408, wrap);
                transferToReceivedDataArray(476, wrap);
                isDataSet2Ready = true;
                isDataReady = false;
            }
            else if(currDataSet == 3){
                Log.e("Parsing", "Data Set 3" + ", " + String.valueOf(wrap.capacity()));
//                transferToReceivedDataArray(408, wrap);
                transferToReceivedDataArray(952, wrap);
                isDataSet3Ready = true;
            }
            else if(currDataSet == 4){
                Log.e("Parsing", "Data Set 4" + ", " + String.valueOf(wrap.capacity()));
//                transferToReceivedDataArray(408, wrap);
                transferToReceivedDataArray(1428, wrap);
                isDataSet4Ready = true;
            }
        }
        else if(wrap.capacity() == 344){
            Log.e("DataReceived",  "Battery level information: " + String.valueOf(wrap.capacity()));

            // Populate received data array with dark current values
            transferToReceivedDataArray(1904, wrap);

            // process the parsed data
            processDataArray();

            // Get the latest time stamp
            durationDataRoundSeconds = durationDataRound / 1000.0f;
            durationDataRound = 0;

            if ((isDataSet1Ready && isDataSet2Ready) && (isDataSet3Ready && isDataSet4Ready)){
                isDataReady = true;
                isDataSet1Ready = false;
                isDataSet2Ready = false;
                isDataSet3Ready = false;
                isDataSet4Ready = false;
            }

        }

        return new CustomDataBundle(dataArray, isDataReady, durationDataRoundSeconds, batteryPercentage, ledIntensityValues, darkCurrentMeasurements);
    }


    public void transferToReceivedDataArray(int overwriteStartIndex, ByteBuffer wrap){

        // Use a loop to replace the values at the specified range
        // start from byte # 4 to skip the first element
        for (int i = 4; i < wrap.capacity(); i++) {
//            Log.e("Parsing", "OverWriteStartIndex: " + String.valueOf(overwriteStartIndex + i -4) + " , " + String.valueOf(receivedDataArray.length) + " Wrap Capacity: " + String.valueOf(wrap.capacity()));
            receivedDataArray[overwriteStartIndex + i - 4] = wrap.get(i); // populate the byte array
        }

    }

    public void processDataArray(){

        ByteBuffer wrap = ByteBuffer.wrap(receivedDataArray);
        wrap.order(ByteOrder.LITTLE_ENDIAN);

        for (int i = 0; i < receivedDataArray.length; i+=4){

            int currentElement = i/4;
            int sourceIndex = (int) Math.floor(currentElement / 17);
            int detectorIndex = currentElement - (sourceIndex * 17); // values 1 through 17

            // Extract the current set of bytes
            int currentInt = wrap.getInt(i);

            if (sourceIndex == 32){
                if (detectorIndex == 16){
                    durationDataRound = durationDataRound + currentInt;
                }
                else{
                    double currentValue = convertADCValueToDouble(currentInt, 1);
                    darkCurrentMeasurements[detectorIndex] = currentValue;
                }
            }
            else{
                if (detectorIndex == 16){
                    durationDataRound = durationDataRound + currentInt;
                }
                else{
//                    Log.e("ProcessDataArray", "Source: " +  String.valueOf(sourceIndex) + " , " + " Detector: " + String.valueOf(detectorIndex));// " index: " + String.valueOf((sourceIndex*17)+detectorIndex));
                    double currentValue = convertADCValueToDouble(currentInt, 1);
//                Log.e("Parsing", "Source: " + String.valueOf(sourceIndex) + " , Detector " + String.valueOf(detectorIndex));
                    dataArray[sourceIndex][detectorIndex] = currentValue;
                }
            }

        }

    }

    public double convertADCValueToDouble(int currInteger, int pgaValue){

        double VREF = 2.50;

        int bit24 = (currInteger >> 23) & 1;

        if (bit24 == 1) //if the 24th bit (sign) is 1, the number is negative
        {
            currInteger = currInteger - 16777216;  //conversion for the negative sign
            //"mirroring" around zero
        }

        double outputVoltage = ((2*VREF) / 8388608.0) * currInteger;
        double scaledVoltage = outputVoltage/pgaValue;

        return scaledVoltage;

    }

}
