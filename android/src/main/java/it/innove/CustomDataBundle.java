package it.innove;

import java.util.ArrayList;

public class CustomDataBundle {

    double[][] dataArray = new double[24][16];
    Boolean isDataReady;
    float durationDataRoundSeconds = 0;
    int batteryPercentage;

    double[] darkCurrentMeasurements = new double[16];
    int[] ledIntensityValues = new int[16];

    public CustomDataBundle(double[][] dataArray, Boolean isDataReady, float durationDataRoundSeconds,
            int batteryPercentage, int[] ledIntensityValues, double[] darkCurrentMeasurements) {
        super();
        this.dataArray = dataArray;
        this.isDataReady = isDataReady;
        this.durationDataRoundSeconds = durationDataRoundSeconds;
        this.batteryPercentage = batteryPercentage;
        this.ledIntensityValues = ledIntensityValues;
        this.darkCurrentMeasurements = darkCurrentMeasurements;
    }

    public Boolean checkIfDataReady() {
        return isDataReady;
    }

    public double[][] getDataArray() {
        return dataArray;
    }

    public float getDurationDataRoundSeconds() {
        return durationDataRoundSeconds;
    }

    public int getBatteryPercentage() {
        return batteryPercentage;
    }

    public double[] getDarkCurrentMeasurements() {
        return darkCurrentMeasurements;
    }
}