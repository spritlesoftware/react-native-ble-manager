package it.innove;

import android.app.Activity;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothProfile;
import android.content.Context;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import androidx.annotation.Nullable;
import android.util.Base64;
import android.util.Log;
import android.os.Environment;


import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.RCTNativeAppEventEmitter;

import org.json.JSONException;

import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Map;
import java.util.HashMap;
import java.util.Arrays;
import java.util.Iterator;
import java.util.List;
import java.util.UUID;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Calendar;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.List;

import static android.os.Build.VERSION_CODES.LOLLIPOP;
import static com.facebook.react.common.ReactConstants.TAG;

/**
 * Peripheral wraps the BluetoothDevice and provides methods to convert to JSON.
 */
public class Peripheral extends BluetoothGattCallback {

	private static final String CHARACTERISTIC_NOTIFICATION_CONFIG = "00002902-0000-1000-8000-00805f9b34fb";

	public float ch1R, ch2R, ch3R, ch4R, ch5R, ch6R, ch7R, ch8R, ch9R, ch10R, ch11R, ch12R, ch13R, ch14R, ch15R, ch16R, ch17R;
	public float ch1Rs, ch2Rs, ch3Rs, ch4Rs, ch5Rs, ch6Rs, ch7Rs, ch8Rs, ch9Rs, ch10Rs, ch11Rs, ch12Rs, ch13Rs, ch14Rs, ch15Rs, ch16Rs, ch17Rs;
	public float ch1IR, ch2IR, ch3IR, ch4IR, ch5IR, ch6IR, ch7IR, ch8IR, ch9IR, ch10IR, ch11IR, ch12IR, ch13IR, ch14IR, ch15IR, ch16IR, ch17IR;
	public float ch1IRs, ch2IRs, ch3IRs, ch4IRs, ch5IRs, ch6IRs, ch7IRs, ch8IRs, ch9IRs, ch10IRs, ch11IRs, ch12IRs, ch13IRs, ch14IRs, ch15IRs, ch16IRs, ch17IRs;
	public float accDataX, accDataY, accDataZ, magDataX, magDataY, magDataZ, gyroDataX, gyroDataY, gyroDataZ;
	public float d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11, d12;
	public double[][] valuesR = new double[100][16];
	public double[][] valuesIR = new double[100][16];
	public int snrDataBufferSize = 0;
	String fileNames = "";
//	String[] games = {"SkipX", "BMW", "Ford", "Mazda"};

	private final BluetoothDevice device;
	private final Map<String, NotifyBufferContainer> bufferedCharacteristics;
	protected byte[] advertisingDataBytes = new byte[0];
	protected int advertisingRSSI;
	private boolean connected = false;
	private ReactContext reactContext;

	private BluetoothGatt gatt;

	private Callback connectCallback;
	private Callback retrieveServicesCallback;
	private Callback readCallback;
	private Callback readRSSICallback;
	private Callback writeCallback;
	private Callback registerNotifyCallback;
	private Callback requestMTUCallback;
	//public DataProcessing processor;


	BluetoothGattCharacteristic mcharacteristic = null;
  BluetoothGattService adcService;
  BluetoothGattService ledService;

	Long tsStart;
  Long tsLong;
  String ts;

	List<BluetoothGattCharacteristic> adc_characteristics = new ArrayList<>();
  List<BluetoothGattCharacteristic> imu_characteristics = new ArrayList<>();
  List<BluetoothGattCharacteristic> led_characteristics = new ArrayList<>();
  BluetoothGattCharacteristic ledEvent_char;

	public boolean eventState = true;
  public boolean streamingState = false;
  public byte[] eventValue;

  public byte[] dataArray;

	File dataFile;
  File localFile;
  OutputStreamWriter writer;
  String message;

	private List<byte[]> writeQueue = new ArrayList<>();

	public Peripheral(BluetoothDevice device, int advertisingRSSI, byte[] scanRecord, ReactContext reactContext) {
		this.device = device;
		this.bufferedCharacteristics = new HashMap<String, NotifyBufferContainer>();
		this.advertisingRSSI = advertisingRSSI;
		this.advertisingDataBytes = scanRecord;
		this.reactContext = reactContext;
	}

	public Peripheral(BluetoothDevice device, ReactContext reactContext) {
		this.device = device;
		this.bufferedCharacteristics = new HashMap<String, NotifyBufferContainer>();
		this.reactContext = reactContext;
	}

	private void sendEvent(String eventName, @Nullable WritableMap params) {
		reactContext.getJSModule(RCTNativeAppEventEmitter.class).emit(eventName, params);
	}

	private void sendConnectionEvent(BluetoothDevice device, String eventName, int status) {
		WritableMap map = Arguments.createMap();
		map.putString("peripheral", device.getAddress());
		if (status != -1) {
			map.putInt("status", status);
		}
		sendEvent(eventName, map);
		Log.d(BleManager.LOG_TAG, "Peripheral event (" + eventName + "):" + device.getAddress());
	}

	public void connect(Callback callback, Activity activity) {
		if (!connected) {
			BluetoothDevice device = getDevice();
			this.connectCallback = callback;
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
				Log.d(BleManager.LOG_TAG, " Is Or Greater than M $mBluetoothDevice");
				gatt = device.connectGatt(activity, false, this, BluetoothDevice.TRANSPORT_LE);
			} else {
				Log.d(BleManager.LOG_TAG, " Less than M");
				try {
					Log.d(BleManager.LOG_TAG, " Trying TRANPORT LE with reflection");
					Method m = device.getClass().getDeclaredMethod("connectGatt", Context.class, Boolean.class,
							BluetoothGattCallback.class, Integer.class);
					m.setAccessible(true);
					Integer transport = device.getClass().getDeclaredField("TRANSPORT_LE").getInt(null);
					gatt = (BluetoothGatt) m.invoke(device, activity, false, this, transport);
				} catch (Exception e) {
					e.printStackTrace();
					Log.d(TAG, " Catch to call normal connection");
					gatt = device.connectGatt(activity, false, this);
				}
			}
		} else {
			if (gatt != null) {
				callback.invoke();
			} else {
				callback.invoke("BluetoothGatt is null");
			}
		}
	}
	// bt_btif : Register with GATT stack failed.

	public void disconnect(boolean force) {
		connectCallback = null;
		connected = false;
		clearBuffers();
		if (gatt != null) {
			try {
				gatt.disconnect();
				if (force) {
					gatt.close();
					gatt = null;
					sendConnectionEvent(device, "BleManagerDisconnectPeripheral", BluetoothGatt.GATT_SUCCESS);
				}
				Log.d(BleManager.LOG_TAG, "Disconnect");
			} catch (Exception e) {
				sendConnectionEvent(device, "BleManagerDisconnectPeripheral", BluetoothGatt.GATT_FAILURE);
				Log.d(BleManager.LOG_TAG, "Error on disconnect", e);
			}
		} else
			Log.d(BleManager.LOG_TAG, "GATT is null");
	}

	public WritableMap asWritableMap() {
		WritableMap map = Arguments.createMap();
		WritableMap advertising = Arguments.createMap();

		try {
			map.putString("name", device.getName());
			map.putString("id", device.getAddress()); // mac address
			map.putInt("rssi", advertisingRSSI);

			String name = device.getName();
			if (name != null)
				advertising.putString("localName", name);

			advertising.putMap("manufacturerData", byteArrayToWritableMap(advertisingDataBytes));

			// No scanResult to access so we can't check if peripheral is connectable
			advertising.putBoolean("isConnectable", true);

			map.putMap("advertising", advertising);
		} catch (Exception e) { // this shouldn't happen
			e.printStackTrace();
		}

		return map;
	}

	public WritableMap asWritableMap(BluetoothGatt gatt) {

		WritableMap map = asWritableMap();

		WritableArray servicesArray = Arguments.createArray();
		WritableArray characteristicsArray = Arguments.createArray();

		if (connected && gatt != null) {
			for (Iterator<BluetoothGattService> it = gatt.getServices().iterator(); it.hasNext();) {
				BluetoothGattService service = it.next();
				WritableMap serviceMap = Arguments.createMap();
				serviceMap.putString("uuid", UUIDHelper.uuidToString(service.getUuid()));

				for (Iterator<BluetoothGattCharacteristic> itCharacteristic = service.getCharacteristics()
						.iterator(); itCharacteristic.hasNext();) {
					BluetoothGattCharacteristic characteristic = itCharacteristic.next();
					WritableMap characteristicsMap = Arguments.createMap();

					characteristicsMap.putString("service", UUIDHelper.uuidToString(service.getUuid()));
					characteristicsMap.putString("characteristic", UUIDHelper.uuidToString(characteristic.getUuid()));

					characteristicsMap.putMap("properties", Helper.decodeProperties(characteristic));

					if (characteristic.getPermissions() > 0) {
						characteristicsMap.putMap("permissions", Helper.decodePermissions(characteristic));
					}

					WritableArray descriptorsArray = Arguments.createArray();

					for (BluetoothGattDescriptor descriptor : characteristic.getDescriptors()) {
						WritableMap descriptorMap = Arguments.createMap();
						descriptorMap.putString("uuid", UUIDHelper.uuidToString(descriptor.getUuid()));
						if (descriptor.getValue() != null) {
							descriptorMap.putString("value",
									Base64.encodeToString(descriptor.getValue(), Base64.NO_WRAP));
						} else {
							descriptorMap.putString("value", null);
						}

						if (descriptor.getPermissions() > 0) {
							descriptorMap.putMap("permissions", Helper.decodePermissions(descriptor));
						}
						descriptorsArray.pushMap(descriptorMap);
					}
					if (descriptorsArray.size() > 0) {
						characteristicsMap.putArray("descriptors", descriptorsArray);
					}
					characteristicsArray.pushMap(characteristicsMap);
				}
				servicesArray.pushMap(serviceMap);
			}
			map.putArray("services", servicesArray);
			map.putArray("characteristics", characteristicsArray);
		}

		return map;
	}

	static WritableMap byteArrayToWritableMap(byte[] bytes) throws JSONException {
		WritableMap object = Arguments.createMap();
		object.putString("CDVType", "ArrayBuffer");
		object.putString("data", bytes != null ? Base64.encodeToString(bytes, Base64.NO_WRAP) : null);
		object.putArray("bytes", bytes != null ? BleManager.bytesToWritableArray(bytes) : null);
		return object;
	}

	public boolean isConnected() {
		return connected;
	}

	public BluetoothDevice getDevice() {
		return device;
	}

	public Boolean hasService(UUID uuid) {
		if (gatt == null) {
			return null;
		}
		return gatt.getService(uuid) != null;
	}

	public static byte[] hexStringToByteArray(String s) {
    int len = s.length();
    byte[] data = new byte[len/2];

    for(int i = 0; i < len; i+=2){
      data[i/2] = (byte) ((Character.digit(s.charAt(i), 16) << 4) + Character.digit(s.charAt(i+1), 16));
    }

    return data;
  }

	@Override
	public void onServicesDiscovered(BluetoothGatt gatt, int status) {
		super.onServicesDiscovered(gatt, status);

		Log.d(BleManager.LOG_TAG,"onServicesDiscovered");

		for (BluetoothGattService service : gatt.getServices()) {

			if ((service == null) || (service.getUuid() == null)) {
				continue;
			}

			if (status == BluetoothGatt.GATT_SUCCESS) {

				List<BluetoothGattService> services = gatt.getServices();

				// Loop through all the GATT services
				for (BluetoothGattService service1 : services) {

					Log.e(TAG, service1.getUuid().toString()+"###Ser");

					// Check ADC values service
					if (service1.getUuid().toString().toLowerCase().contains("938548e6-c655-11ea-87d0-0242ac130003")) {
						adcService = service1;
						adc_characteristics = service1.getCharacteristics();

						for (BluetoothGattCharacteristic characteristic : adc_characteristics) {

							if (characteristic.getUuid().toString().contains("77539407-6493-4b89-985f-baaf4c0f8d86")) {
								Log.d(BleManager.LOG_TAG, "1st Notification UUID identified");
								UUID currUUID = characteristic.getUuid();
								gatt.setCharacteristicNotification(characteristic, true);
								BluetoothGattDescriptor desc = characteristic.getDescriptor(UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"));
								desc.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
								gatt.writeDescriptor(desc);
							}

						}
					}

					// Check LED values service
					if (service1.getUuid().toString().toLowerCase().equals("19b10000-e8f2-537e-4f6c-d104768a1214")) {
						ledService = service1;
						led_characteristics = service1.getCharacteristics();
						for (BluetoothGattCharacteristic characteristic : led_characteristics) {
							if (characteristic.getUuid().toString().contains("19b10001-e8f2-537e-4f6c-d104768a1213")) {
								Log.d(BleManager.LOG_TAG, "event char detected");
								//connectionstatus.setText("CONNECTED");
								ledEvent_char = characteristic;
								if (retrieveServicesCallback != null) {
									WritableMap map = this.asWritableMap(gatt);
									retrieveServicesCallback.invoke(null, map);
									retrieveServicesCallback = null;
								}
							}
						}
					}
				}

			}

		}
		String message = "MTU Request result: " + String.valueOf(gatt.requestMtu(129));
		Log.d(TAG, message);

		// if (retrieveServicesCallback != null) {
		// 	WritableMap map = this.asWritableMap(gatt);
		// 	retrieveServicesCallback.invoke(null, map);
		// 	retrieveServicesCallback = null;
		// }
	}

	@Override
	public void onConnectionStateChange(BluetoothGatt gatta, int status, int newState) {

		Log.d(BleManager.LOG_TAG, "onConnectionStateChange to " + newState + " on peripheral: " + device.getAddress()
				+ " with status " + status);

		gatt = gatta;

		if (status != BluetoothGatt.GATT_SUCCESS) {
		    gatt.close();
		}

		if (newState == BluetoothProfile.STATE_CONNECTED) {
			connected = true;

			sendConnectionEvent(device, "BleManagerConnectPeripheral", status);

			if (connectCallback != null) {
				Log.d(BleManager.LOG_TAG, "Connected to: " + device.getAddress());
				connectCallback.invoke();
				connectCallback = null;
			}

		} else if (newState == BluetoothProfile.STATE_DISCONNECTED) {

			this.disconnect(true);

			sendConnectionEvent(device, "BleManagerDisconnectPeripheral", status);
			List<Callback> callbacks = Arrays.asList(writeCallback, retrieveServicesCallback, readRSSICallback,
					readCallback, registerNotifyCallback, requestMTUCallback);
			for (Callback currentCallback : callbacks) {
				if (currentCallback != null) {
					currentCallback.invoke("Device disconnected");
				}
			}
			if (connectCallback != null) {
				connectCallback.invoke("Connection error");
				connectCallback = null;
			}
			writeCallback = null;
			writeQueue.clear();
			readCallback = null;
			retrieveServicesCallback = null;
			readRSSICallback = null;
			registerNotifyCallback = null;
			requestMTUCallback = null;
		}

	}

	public void updateRssi(int rssi) {
		advertisingRSSI = rssi;
	}

	public void updateData(byte[] data) {
		advertisingDataBytes = data;
	}

	public int unsignedToBytes(byte b) {
		return b & 0xFF;
	}

	@Override
	public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic) {
		dataArray = characteristic.getValue();
		tsLong = System.currentTimeMillis() - tsStart;
		float timeSeconds = (float) ((float) tsLong / 1000.0);
		String timerstring = String.format("%.2f", timeSeconds);
		message = convertByteToChannelData(ByteBuffer.wrap(dataArray), timerstring, 0);
		writeFileOnInternalStorage(message);
		Log.d(BleManager.LOG_TAG, message);
	}

	public void writeFileOnInternalStorage(String value){

		try {
			FileWriter writer = new FileWriter(localFile, true);
			writer.append(value);
			writer.flush();
			writer.close();
		} catch (Exception e){
			e.printStackTrace();
		}
  }

	public static void copy(File origin, File dest) throws IOException {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      Files.copy(origin.toPath(), dest.toPath());
    }
  }

	public void copyFileToExternalStorage() throws IOException {

		Log.d(BleManager.LOG_TAG, "copyFileToExternalStorage");


    // Reference:
    // https://stackoverflow.com/questions/41782162/how-to-write-file-into-dcim-directory-exactly-where-camera-does
    String data_folder = "BBOL_fNIRS";
    File f = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM), data_folder);
    if (!f.exists()) {
      f.mkdirs();
    }

    DateFormat df = new SimpleDateFormat("yyyy-MM-dd-HH-mm-ss");
    String date = df.format(Calendar.getInstance().getTime());
    String fname = date + ".csv";

		Log.e(BleManager.LOG_TAG, "fname");


    dataFile = new File(f, fname);
    
    // if(!dataFile.exists()){
    //  dataFile.createNewFile();
    // }

    copy(localFile, dataFile);

    localFile.delete();

    Log.e(BleManager.LOG_TAG, fname);

    //connectionstatus.setText("FILE SAVED!");

  }


	public String convertByteToChannelData(ByteBuffer wrap,String timerString, int stimulus){

		wrap.order(ByteOrder.LITTLE_ENDIAN);

		// Set 1 Channels
		// Channels 1, 5, 6, 11, 16, 17
		ch1R = (float) ((wrap.getShort(0) / 4095.) * 3.3);
		ch1Rs =  (float) ((wrap.getShort(4) / 4095.) * 3.3);
		ch5R =  (float) ((wrap.getShort(12) / 4095.) * 3.3);
		ch5Rs =  (float) ((wrap.getShort(4) / 4095.) * 3.3);
		ch6R =  (float) ((wrap.getShort(6) / 4095.) * 3.3);
		ch6Rs =  (float) ((wrap.getShort(4) / 4095.) * 3.3);
		ch11R =  (float) ((wrap.getShort(2) / 4095.) * 3.3);
		ch11Rs =  (float) ((wrap.getShort(8) / 4095.) * 3.3);
		ch16R =  (float) ((wrap.getShort(14) / 4095.) * 3.3);
		ch16Rs =  (float) ((wrap.getShort(8) / 4095.) * 3.3);
		ch17R =  (float) ((wrap.getShort(16) / 4095.) * 3.3);
		ch17Rs =  (float) ((wrap.getShort(10) / 4095.) * 3.3);

		ch1IR =  (float) ((wrap.getShort(18) / 4095.) * 3.3);
		ch1IRs =  (float) ((wrap.getShort(22) / 4095.) * 3.3);
		ch5IR =  (float) ((wrap.getShort(30) / 4095.) * 3.3);
		ch5IRs =  (float) ((wrap.getShort(22) / 4095.) * 3.3);
		ch6IR =  (float) ((wrap.getShort(24) / 4095.) * 3.3);
		ch6IRs  =  (float) ((wrap.getShort(22) / 4095.) * 3.3);
		ch11IR =  (float) ((wrap.getShort(20) / 4095.) * 3.3);
		ch11IRs  =  (float) ((wrap.getShort(26) / 4095.) * 3.3);
		ch16IR =  (float) ((wrap.getShort(32) / 4095.) * 3.3);
		ch16IRs  =  (float) ((wrap.getShort(26) / 4095.) * 3.3);
		ch17IR =  (float) ((wrap.getShort(34) / 4095.) * 3.3);
		ch17IRs  =  (float) ((wrap.getShort(28) / 4095.) * 3.3);

		// Set 2 Long Channels
		// Channels 4, 7, 12, 13, 14, 15

		ch4R =  (float) ((wrap.getShort(38) / 4095.) * 3.3);
		ch4Rs =  (float) ((wrap.getShort(40) / 4095.) * 3.3);
		ch7R =  (float) ((wrap.getShort(36) / 4095.) * 3.3);
		ch7Rs  =  (float) ((wrap.getShort(42) / 4095.) * 3.3);
		ch12R =  (float) ((wrap.getShort(46) / 4095.) * 3.3);
		ch12Rs  =  (float) ((wrap.getShort(40) / 4095.) * 3.3);
		ch13R =  (float) ((wrap.getShort(52) / 4095.) * 3.3);
		ch13Rs  =  (float) ((wrap.getShort(40) / 4095.) * 3.3);
		ch14R =  (float) ((wrap.getShort(48) / 4095.) * 3.3);
		ch14Rs  =  (float) ((wrap.getShort(42) / 4095.) * 3.3);
		ch15R =  (float) ((wrap.getShort(50) / 4095.) * 3.3);
		ch15Rs  =  (float) ((wrap.getShort(44) / 4095.) * 3.3);

		ch4IR =  (float) ((wrap.getShort(56) / 4095.) * 3.3);
		ch4IRs  =  (float) ((wrap.getShort(58) / 4095.) * 3.3);
		ch7IR =  (float) ((wrap.getShort(54) / 4095.) * 3.3);
		ch7IRs  =  (float) ((wrap.getShort(60) / 4095.) * 3.3);
		ch12IR =  (float) ((wrap.getShort(64) / 4095.) * 3.3);
		ch12IRs  =  (float) ((wrap.getShort(58) / 4095.) * 3.3);
		ch13IR =  (float) ((wrap.getShort(70) / 4095.) * 3.3);
		ch13IRs  =  (float) ((wrap.getShort(58) / 4095.) * 3.3);
		ch14IR =  (float) ((wrap.getShort(66) / 4095.) * 3.3);
		ch14IRs  =  (float) ((wrap.getShort(60) / 4095.) * 3.3);
		ch15IR =  (float) ((wrap.getShort(68) / 4095.) * 3.3);
		ch15IRs  =  (float) ((wrap.getShort(62) / 4095.) * 3.3);

		// Set 3 Long Channels
		// Channels 2, 3,8, 9, 10

		ch2R =  (float) ((wrap.getShort(72) / 4095.) * 3.3);
		ch2Rs =  (float) ((wrap.getShort(76) / 4095.) * 3.3);
		ch3R =  (float) ((wrap.getShort(74) / 4095.) * 3.3);
		ch3Rs =  (float) ((wrap.getShort(76) / 4095.) * 3.3);
		ch8R =  (float) ((wrap.getShort(78) / 4095.) * 3.3);
		ch8Rs =  (float) ((wrap.getShort(76) / 4095.) * 3.3);
		ch9R =  (float) ((wrap.getShort(82) / 4095.) * 3.3);
		ch9Rs =  (float) ((wrap.getShort(76) / 4095.) * 3.3);
		ch10R =  (float) ((wrap.getShort(80) / 4095.) * 3.3);
		ch10Rs =  (float) ((wrap.getShort(76) / 4095.) * 3.3);

		ch2IR =  (float) ((wrap.getShort(84) / 4095.) * 3.3);
		ch2IRs =  (float) ((wrap.getShort(88) / 4095.) * 3.3);
		ch3IR =  (float) ((wrap.getShort(86) / 4095.) * 3.3);
		ch3IRs =  (float) ((wrap.getShort(88) / 4095.) * 3.3);
		ch8IR =  (float) ((wrap.getShort(90) / 4095.) * 3.3);
		ch8IRs =  (float) ((wrap.getShort(88) / 4095.) * 3.3);
		ch9IR =  (float) ((wrap.getShort(94) / 4095.) * 3.3);
		ch9IRs =  (float) ((wrap.getShort(88) / 4095.) * 3.3);
		ch10IR =  (float) ((wrap.getShort(92) / 4095.) * 3.3);
		ch10IRs =  (float) ((wrap.getShort(88) / 4095.) * 3.3);

		d1 = (float) ((wrap.getShort(0) / 4095.) * 3.3);
		d2 = (float) ((wrap.getShort(2) / 4095.) * 3.3);
		d3 = (float) ((wrap.getShort(4) / 4095.) * 3.3);
		d4 = (float) ((wrap.getShort(76) / 4095.) * 3.3);
		d5 = (float) ((wrap.getShort(40) / 4095.) * 3.3);
		d6 = (float) ((wrap.getShort(6) / 4095.) * 3.3);
		d7 = (float) ((wrap.getShort(90) / 4095.) * 3.3);
		d8 = (float) ((wrap.getShort(26) / 4095.) * 3.3);
		d9 = (float) ((wrap.getShort(28) / 4095.) * 3.3);
		d10 = (float) ((wrap.getShort(4) / 4095.) * 3.3);
		d11 = (float) ((wrap.getShort(32) / 4095.) * 3.3);
		d12 = (float) ((wrap.getShort(34) / 4095.) * 3.3);

		// dataValueDisplays.get(0).setText(String.valueOf(d1));
		// dataValueDisplays.get(1).setText(String.valueOf(d2));
		// dataValueDisplays.get(2).setText(String.valueOf(d3));
		// dataValueDisplays.get(3).setText(String.valueOf(d4));
		// dataValueDisplays.get(4).setText(String.valueOf(d5));
		// dataValueDisplays.get(5).setText(String.valueOf(d6));
		// dataValueDisplays.get(6).setText(String.valueOf(d7));
		// dataValueDisplays.get(7).setText(String.valueOf(d8));
		// dataValueDisplays.get(8).setText(String.valueOf(d9));
		// dataValueDisplays.get(9).setText(String.valueOf(d10));
		// dataValueDisplays.get(10).setText(String.valueOf(d11));
		// dataValueDisplays.get(11).setText(String.valueOf(d12));
//
//        accDataX = (float) (wrap.getShort(96) - 10000) / 100;
//        accDataY = (float) (wrap.getShort(98) - 10000) / 100;
//        accDataZ = (float) (wrap.getShort(100) - 10000) / 100;
//        magDataX = (float) (wrap.getShort(102) - 10000) / 100;
//        magDataY = (float) (wrap.getShort(104) - 10000) / 100;
//        magDataZ = (float) (wrap.getShort(106) - 10000) / 100;
//        gyroDataX = (float) (wrap.getShort(108) - 10000) / 100;
//        gyroDataY = (float) (wrap.getShort(110) - 10000) / 100;
//        gyroDataZ = (float) (wrap.getShort(112) - 10000) / 100;

		String message = timerString +
						"," + ch1R +
						"," + ch1Rs +
						"," + ch1IR +
						"," + ch1Rs +
						"," + ch2R +
						"," + ch2Rs +
						"," + ch2IR +
						"," + ch2IRs +
						"," + ch3R +
						"," + ch3Rs +
						"," + ch3IR +
						"," + ch3IRs +
						"," + ch4R +
						"," + ch4Rs +
						"," + ch4IR +
						"," + ch4IRs +
						"," + ch5R +
						"," + ch5Rs +
						"," + ch5IR +
						"," + ch5IRs +
						"," + ch6R +
						"," + ch6Rs +
						"," + ch6IR +
						"," + ch6IRs +
						"," + ch7R +
						"," + ch7Rs +
						"," + ch7IR +
						"," + ch7IRs +
						"," + ch8R +
						"," + ch8Rs +
						"," + ch8IR +
						"," + ch8IRs +
						"," + ch9R +
						"," + ch9Rs +
						"," + ch9IR +
						"," + ch9IRs +
						"," + ch10R +
						"," + ch10Rs +
						"," + ch10IR +
						"," + ch10IRs +
						"," + ch11R +
						"," + ch11Rs +
						"," + ch11IR +
						"," + ch11IRs +
						"," + ch12R +
						"," + ch12Rs +
						"," + ch12IR +
						"," + ch12IRs +
						"," + ch13R +
						"," + ch13Rs +
						"," + ch13IR +
						"," + ch13IRs +
						"," + ch14R +
						"," + ch14Rs +
						"," + ch14IR +
						"," + ch14IRs +
						"," + ch15R +
						"," + ch15Rs +
						"," + ch15IR +
						"," + ch15IRs +
						"," + ch16R +
						"," + ch16Rs +
						"," + ch16IR +
						"," + ch16IRs +
						"," + ch17R +
						"," + ch17Rs +
						"," + ch17IR +
						"," + ch17IRs +
//                "," + String.valueOf(accDataX) +
//                "," + String.valueOf(accDataY) +
//                "," + String.valueOf(accDataZ) +
//                "," + String.valueOf(magDataX) +
//                "," + String.valueOf(magDataY) +
//                "," + String.valueOf(magDataZ) +
//                "," + String.valueOf(gyroDataX) +
//                "," + String.valueOf(gyroDataY) +
//                "," + String.valueOf(gyroDataZ) +
						"\r\n";

		double[] channelValuesR = {ch1R, ch2R, ch3R, ch4R, ch5R, ch6R, ch7R, ch8R, ch9R, ch10R, ch11R, ch12R, ch13R, ch14R, ch15R, ch16R};
		double[] channelValuesIR = {ch1IR, ch2IR, ch3IR, ch4IR, ch5IR, ch6IR, ch7IR, ch8IR, ch9IR, ch10IR, ch11IR, ch12IR, ch13IR, ch14IR, ch15IR, ch16IR};

		if (snrDataBufferSize > 99){

				//Reset buffer counter to 0
				snrDataBufferSize = 0;

				//Get signal SNR
				getSNR();

		}
		else{

				//Build double array values with 16 channels of value
				valuesR[snrDataBufferSize] = channelValuesR;
				valuesIR[snrDataBufferSize] = channelValuesIR;

				//Iterate bufferSize counter
				snrDataBufferSize++;

		}

		//Log.d("fNIRSdata", message);

		return message;

		// Log to data file
		//writeFileOnInternalStorage(localFile, message);

}

public void getSNR(){

		double meanR =0, meanIR = 0;
		double[] channelWiseSNR_R = new double[16];
		double[] channelWiseSNR_IR = new double[16];

		for (int channel = 0; channel<=15; channel++){

				// Get DC component

				for (int i = 0; i<=99; i++){
						meanR = meanR + valuesR[i][channel];
						meanIR = meanIR + valuesIR[i][channel];
				}

				meanR = meanR / 100;
				meanIR = meanIR / 100;

				// Get Variance of AC component
				double varianceR = 0;
				double varianceIR = 0;
				for (int i = 0; i <= 99; i++) {
						varianceR += Math.pow(valuesR[i][channel] - meanR, 2);
						varianceIR += Math.pow(valuesIR[i][channel] - meanIR, 2);
				}
				varianceR = varianceR/100;
				varianceIR = varianceIR/100;

				channelWiseSNR_R[channel] = 20*Math.log10(meanR/varianceR);
				channelWiseSNR_IR[channel] = 20*Math.log10(meanIR/varianceIR);

		}

		String snrValuesR = channelWiseSNR_R[0] + "," +
						channelWiseSNR_R[1] + "," +
						channelWiseSNR_R[2] + "," +
						channelWiseSNR_R[3] + "," +
						channelWiseSNR_R[4] + "," +
						channelWiseSNR_R[5] + "," +
						channelWiseSNR_R[6] + "," +
						channelWiseSNR_R[7] + "," +
						channelWiseSNR_R[8] + "," +
						channelWiseSNR_R[9] + "," +
						channelWiseSNR_R[10] + "," +
						channelWiseSNR_R[11] + "," +
						channelWiseSNR_R[12] + "," +
						channelWiseSNR_R[13] + "," +
						channelWiseSNR_R[14] + "," +
						channelWiseSNR_R[15];

		String snrValuesIR = channelWiseSNR_IR[0] + "," +
						channelWiseSNR_IR[1] + "," +
						channelWiseSNR_IR[2] + "," +
						channelWiseSNR_IR[3] + "," +
						channelWiseSNR_IR[4] + "," +
						channelWiseSNR_IR[5] + "," +
						channelWiseSNR_IR[6] + "," +
						channelWiseSNR_IR[7] + "," +
						channelWiseSNR_IR[8] + "," +
						channelWiseSNR_IR[9] + "," +
						channelWiseSNR_IR[10] + "," +
						channelWiseSNR_IR[11] + "," +
						channelWiseSNR_IR[12] + "," +
						channelWiseSNR_IR[13] + "," +
						channelWiseSNR_IR[14] + "," +
						channelWiseSNR_IR[15];

		Log.d("SNR_Red", snrValuesR);
		Log.d("SNR_Infrared", snrValuesIR);

}

	//////

	// @Override
	// public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic) {
	// 	super.onCharacteristicChanged(gatt, characteristic);
	// 	try {
	// 		String charString = characteristic.getUuid().toString();
	// 		String service = characteristic.getService().getUuid().toString();
	// 		NotifyBufferContainer buffer = this.bufferedCharacteristics
	// 				.get(this.bufferedCharacteristicsKey(service, charString));
	// 		byte[] dataValue = characteristic.getValue();
	// 		if (buffer != null) {
	// 			buffer.put(dataValue);
	// 			// Log.d(BleManager.LOG_TAG, "onCharacteristicChanged-buffering: " +
	// 			// buffer.size() + " from peripheral: " + device.getAddress());

	// 			if (buffer.size().equals(buffer.maxCount)) {
	// 				Log.d(BleManager.LOG_TAG, "onCharacteristicChanged sending buffered data " + buffer.size());

	// 				// send'm and reset
	// 				dataValue = buffer.items.array();
	// 				buffer.resetBuffer();
	// 			} else {
	// 				return;
	// 			}
	// 		}
	// 		Log.d(BleManager.LOG_TAG, "onCharacteristicChanged: " + BleManager.bytesToHex(dataValue)
	// 				+ " from peripheral: " + device.getAddress());
	// 		WritableMap map = Arguments.createMap();
	// 		map.putString("peripheral", device.getAddress());
	// 		map.putString("characteristic", charString);
	// 		map.putString("service", service);
	// 		map.putArray("value", BleManager.bytesToWritableArray(dataValue));
	// 		sendEvent("BleManagerDidUpdateValueForCharacteristic", map);

	// 	} catch (Exception e) {
	// 		Log.d(BleManager.LOG_TAG, "onCharacteristicChanged ERROR: " + e.toString());
	// 	}
	// }

	@Override
	public void onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status) {
		super.onCharacteristicRead(gatt, characteristic, status);
		Log.d(BleManager.LOG_TAG, "onCharacteristicRead " + characteristic);

		if (readCallback != null) {

			if (status == BluetoothGatt.GATT_SUCCESS) {
				byte[] dataValue = characteristic.getValue();

				if (readCallback != null) {
					readCallback.invoke(null, BleManager.bytesToWritableArray(dataValue));
				}
			} else {
				readCallback.invoke("Error reading " + characteristic.getUuid() + " status=" + status, null);
			}

			readCallback = null;

		}
	}

	@Override
	// public void onCharacteristicWrite(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status) {
	// 	super.onCharacteristicWrite(gatt, characteristic, status);

	// 	if (writeCallback != null) {

	// 		if (writeQueue.size() > 0) {
	// 			byte[] data = writeQueue.get(0);
	// 			writeQueue.remove(0);
	// 			doWrite(characteristic, data);
	// 		} else {

	// 			if (status == BluetoothGatt.GATT_SUCCESS) {
	// 				writeCallback.invoke();
	// 			} else {
	// 				Log.e(BleManager.LOG_TAG, "Error onCharacteristicWrite:" + status);
	// 				writeCallback.invoke("Error writing status: " + status);
	// 			}

	// 			writeCallback = null;
	// 		}
	// 	} else {
	// 		Log.e(BleManager.LOG_TAG, "No callback on write");
	// 	}
	// }

	public void onCharacteristicWrite(BluetoothGatt gatt,BluetoothGattCharacteristic characteristic, int status) {
		if (status != BluetoothGatt.GATT_SUCCESS) {
			Log.e(BleManager.LOG_TAG, "Failed write, retrying: " + status);
			//gatt.writeCharacteristic(characteristic);
			writeCallback.invoke("Error writing status: " + status);
		}
		Log.e(BleManager.LOG_TAG+" onCharacteristicWrite",""+ characteristic.getIntValue(BluetoothGattCharacteristic.FORMAT_UINT8, 0));
		super.onCharacteristicWrite(gatt, characteristic, status);
		gatt.requestMtu(129);
		writeCallback.invoke();
	}

	@Override
	public void onDescriptorWrite(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status) {
		super.onDescriptorWrite(gatt, descriptor, status);
		if (registerNotifyCallback != null) {
			if (status == BluetoothGatt.GATT_SUCCESS) {
				registerNotifyCallback.invoke();
				Log.d(BleManager.LOG_TAG, "onDescriptorWrite success");
			} else {
				registerNotifyCallback.invoke("Error writing descriptor stats=" + status, null);
				Log.e(BleManager.LOG_TAG, "Error writing descriptor stats=" + status);
			}

			registerNotifyCallback = null;
		} else {
			Log.e(BleManager.LOG_TAG, "onDescriptorWrite with no callback");
		}
	}

	@Override
	public void onReadRemoteRssi(BluetoothGatt gatt, int rssi, int status) {
		super.onReadRemoteRssi(gatt, rssi, status);
		if (readRSSICallback != null) {
			if (status == BluetoothGatt.GATT_SUCCESS) {
				updateRssi(rssi);
				readRSSICallback.invoke(null, rssi);
			} else {
				readRSSICallback.invoke("Error reading RSSI status=" + status, null);
			}

			readRSSICallback = null;
		}
	}

	private String bufferedCharacteristicsKey(String serviceUUID, String characteristicUUID) {
		return serviceUUID + "-" + characteristicUUID;
	}

	private void clearBuffers() {
		for (Map.Entry<String, NotifyBufferContainer> entry : this.bufferedCharacteristics.entrySet())
			entry.getValue().resetBuffer();
	}

	private void setNotify(UUID serviceUUID, UUID characteristicUUID, Boolean notify, Integer buffer,
			Callback callback) {
		if (!isConnected()) {
			callback.invoke("Device is not connected", null);
			return;
		}
		Log.d(BleManager.LOG_TAG, "setNotify");

		if (gatt == null) {
			callback.invoke("BluetoothGatt is null");
			return;
		}
		BluetoothGattService service = gatt.getService(serviceUUID);
		BluetoothGattCharacteristic characteristic = findNotifyCharacteristic(service, characteristicUUID);

		if (characteristic != null) {
			if (gatt.setCharacteristicNotification(characteristic, notify)) {

				if (buffer > 1) {
					Log.d(BleManager.LOG_TAG, "Characteristic buffering " + characteristicUUID + " count:" + buffer);
					String key = this.bufferedCharacteristicsKey(serviceUUID.toString(), characteristicUUID.toString());
					this.bufferedCharacteristics.put(key, new NotifyBufferContainer(key, buffer));
				}

				BluetoothGattDescriptor descriptor = characteristic
						.getDescriptor(UUIDHelper.uuidFromString(CHARACTERISTIC_NOTIFICATION_CONFIG));
				if (descriptor != null) {

					// Prefer notify over indicate
					if ((characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0) {
						Log.d(BleManager.LOG_TAG, "Characteristic " + characteristicUUID + " set NOTIFY");
						descriptor.setValue(notify ? BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
								: BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE);
					} else if ((characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0) {
						Log.d(BleManager.LOG_TAG, "Characteristic " + characteristicUUID + " set INDICATE");
						descriptor.setValue(notify ? BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
								: BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE);
					} else {
						Log.d(BleManager.LOG_TAG, "Characteristic " + characteristicUUID
								+ " does not have NOTIFY or INDICATE property set");
					}

					try {
						registerNotifyCallback = callback;
						if (gatt.writeDescriptor(descriptor)) {
							Log.d(BleManager.LOG_TAG, "setNotify complete");
						} else {
							registerNotifyCallback = null;
							callback.invoke(
									"Failed to set client characteristic notification for " + characteristicUUID);
						}
					} catch (Exception e) {
						Log.d(BleManager.LOG_TAG, "Error on setNotify", e);
						callback.invoke("Failed to set client characteristic notification for " + characteristicUUID
								+ ", error: " + e.getMessage());
					}

				} else {
					callback.invoke("Set notification failed for " + characteristicUUID);
				}

			} else {
				callback.invoke("Failed to register notification for " + characteristicUUID);
			}

		} else {
			callback.invoke("Characteristic " + characteristicUUID + " not found");
		}

	}

	public void registerNotify(UUID serviceUUID, UUID characteristicUUID, Integer buffer, Callback callback) {
		Log.d(BleManager.LOG_TAG, "registerNotify");
		this.setNotify(serviceUUID, characteristicUUID, true, buffer, callback);
	}

	public void removeNotify(UUID serviceUUID, UUID characteristicUUID, Callback callback) {
		Log.d(BleManager.LOG_TAG, "removeNotify");
		this.setNotify(serviceUUID, characteristicUUID, false, 1, callback);
	}

	// Some devices reuse UUIDs across characteristics, so we can't use
	// service.getCharacteristic(characteristicUUID)
	// instead check the UUID and properties for each characteristic in the service
	// until we find the best match
	// This function prefers Notify over Indicate
	private BluetoothGattCharacteristic findNotifyCharacteristic(BluetoothGattService service,
			UUID characteristicUUID) {

		try {
			// Check for Notify first
			List<BluetoothGattCharacteristic> characteristics = service.getCharacteristics();
			for (BluetoothGattCharacteristic characteristic : characteristics) {
				if ((characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0
						&& characteristicUUID.equals(characteristic.getUuid())) {
					return characteristic;
				}
			}

			// If there wasn't Notify Characteristic, check for Indicate
			for (BluetoothGattCharacteristic characteristic : characteristics) {
				if ((characteristic.getProperties() & BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0
						&& characteristicUUID.equals(characteristic.getUuid())) {
					return characteristic;
				}
			}

			// As a last resort, try and find ANY characteristic with this UUID, even if it
			// doesn't have the correct properties
			return service.getCharacteristic(characteristicUUID);
		} catch (Exception e) {
			Log.e(BleManager.LOG_TAG, "Error retriving characteristic " + characteristicUUID, e);
			return null;
		}
	}

	public void read(UUID serviceUUID, UUID characteristicUUID, Callback callback) {

		if (!isConnected()) {
			callback.invoke("Device is not connected", null);
			return;
		}
		if (gatt == null) {
			callback.invoke("BluetoothGatt is null", null);
			return;
		}

		BluetoothGattService service = gatt.getService(serviceUUID);
		BluetoothGattCharacteristic characteristic = findReadableCharacteristic(service, characteristicUUID);

		if (characteristic == null) {
			callback.invoke("Characteristic " + characteristicUUID + " not found.", null);
		} else {
			readCallback = callback;
			if (!gatt.readCharacteristic(characteristic)) {
				readCallback = null;
				callback.invoke("Read failed", null);
			}
		}
	}

	public void readRSSI(Callback callback) {
		if (!isConnected()) {
			callback.invoke("Device is not connected", null);
			return;
		}
		if (gatt == null) {
			callback.invoke("BluetoothGatt is null", null);
			return;
		}

		readRSSICallback = callback;

		if (!gatt.readRemoteRssi()) {
			readCallback = null;
			callback.invoke("Read RSSI failed", null);
		}
	}

	public void refreshCache(Callback callback) {
		try {
			Method localMethod = gatt.getClass().getMethod("refresh", new Class[0]);
			if (localMethod != null) {
				boolean res = ((Boolean) localMethod.invoke(gatt, new Object[0])).booleanValue();
				callback.invoke(null, res);
			} else {
				callback.invoke("Could not refresh cache for device.");
			}
		} catch (Exception localException) {
			Log.e(TAG, "An exception occured while refreshing device");
			callback.invoke(localException.getMessage());
		}
	}

	public void retrieveServices(Callback callback) {
		if (!isConnected()) {
			callback.invoke("Device is not connected", null);
			return;
		}
		if (gatt == null) {
			callback.invoke("BluetoothGatt is null", null);
			return;
		}
		this.retrieveServicesCallback = callback;
		gatt.discoverServices();
	}

	// Some peripherals re-use UUIDs for multiple characteristics so we need to
	// check the properties
	// and UUID of all characteristics instead of using
	// service.getCharacteristic(characteristicUUID)
	private BluetoothGattCharacteristic findReadableCharacteristic(BluetoothGattService service,
			UUID characteristicUUID) {

		if (service != null) {
			int read = BluetoothGattCharacteristic.PROPERTY_READ;

			List<BluetoothGattCharacteristic> characteristics = service.getCharacteristics();
			for (BluetoothGattCharacteristic characteristic : characteristics) {
				if ((characteristic.getProperties() & read) != 0
						&& characteristicUUID.equals(characteristic.getUuid())) {
					return characteristic;
				}
			}

			// As a last resort, try and find ANY characteristic with this UUID, even if it
			// doesn't have the correct properties
			return service.getCharacteristic(characteristicUUID);
		}

		return null;
	}

	public boolean doWrite(BluetoothGattCharacteristic characteristic, byte[] data) {
		characteristic.setValue(data);

		if (!gatt.writeCharacteristic(characteristic)) {
			Log.d(BleManager.LOG_TAG, "Error on doWrite");
			return false;
		}
		return true;
	}

	public void write(UUID serviceUUID, UUID characteristicUUID, byte[] data, Integer maxByteSize,
			Integer queueSleepTime, Callback callback, int writeType) {
		if (!isConnected()) {
			callback.invoke("Device is not connected", null);
			return;
		}
		if (gatt == null) {
			callback.invoke("BluetoothGatt is null");
		} else {
			BluetoothGattService service = gatt.getService(serviceUUID);
			BluetoothGattCharacteristic characteristic = findWritableCharacteristic(service, characteristicUUID,
					writeType);

			if (characteristic == null) {
				callback.invoke("Characteristic " + characteristicUUID + " not found.");
			} else {
				characteristic.setWriteType(writeType);

				if (writeQueue.size() > 0) {
					callback.invoke("You have already an queued message");
					return;
				}

				if (writeCallback != null) {
					callback.invoke("You're already writing");
					return;
				}

				if (writeQueue.size() == 0 && writeCallback == null) {

					if (BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT == writeType) {
						writeCallback = callback;
					}

					if (data.length > maxByteSize) {
						int dataLength = data.length;
						int count = 0;
						byte[] firstMessage = null;
						List<byte[]> splittedMessage = new ArrayList<>();

						while (count < dataLength && (dataLength - count > maxByteSize)) {
							if (count == 0) {
								firstMessage = Arrays.copyOfRange(data, count, count + maxByteSize);
							} else {
								byte[] splitMessage = Arrays.copyOfRange(data, count, count + maxByteSize);
								splittedMessage.add(splitMessage);
							}
							count += maxByteSize;
						}
						if (count < dataLength) {
							// Other bytes in queue
							byte[] splitMessage = Arrays.copyOfRange(data, count, data.length);
							splittedMessage.add(splitMessage);
						}

						if (BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT == writeType) {
							writeQueue.addAll(splittedMessage);
							if (!doWrite(characteristic, firstMessage)) {
								writeQueue.clear();
								writeCallback = null;
								callback.invoke("Write failed");
							}
						} else {
							try {
								boolean writeError = false;
								if (!doWrite(characteristic, firstMessage)) {
									writeError = true;
									callback.invoke("Write failed");
								}
								if (!writeError) {
									Thread.sleep(queueSleepTime);
									for (byte[] message : splittedMessage) {
										if (!doWrite(characteristic, message)) {
											writeError = true;
											callback.invoke("Write failed");
											break;
										}
										Thread.sleep(queueSleepTime);
									}
									if (!writeError) {
										callback.invoke();
									}
								}
							} catch (InterruptedException e) {
								callback.invoke("Error during writing");
							}
						}
					} else if (doWrite(characteristic, data)) {
						Log.d(BleManager.LOG_TAG, "Write completed");
						if (BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE == writeType) {
							callback.invoke();
						}
					} else {
						callback.invoke("Write failed");
						writeCallback = null;
					}
				}
			}
		}
	}

	public void StarStopDevice(File sFileName, int gameNo){
		localFile = sFileName;
		Log.e(BleManager.LOG_TAG, connected +"--"+eventState+"StartingDevice");
		if (isConnected()) {
			if (eventState){
				Log.e(BleManager.LOG_TAG, "toggle A");
				eventValue = hexStringToByteArray("01");
				eventState = false;
				tsStart= System.currentTimeMillis();
			}
			else{
				Log.e(BleManager.LOG_TAG, "toggle B");
				eventValue = hexStringToByteArray("00");
				eventState = true;
				if(gameNo == 2){
					try{
						WritableMap map = Arguments.createMap();
						map.putString("file_list", fileNames+localFile.getPath().toString());
						Log.e(BleManager.LOG_TAG, "--"+fileNames);
						//Log.e(BleManager.LOG_TAG, fileNames.toString());
            sendEvent("FilesGenerated", map);
					}catch (Exception e){
						e.printStackTrace();
					}
				}
				else{
					fileNames = fileNames+localFile.getPath().toString()+",";
				}
				// try {
				// 	copyFileToExternalStorage();
				// } catch (IOException e) {
				// 	Log.e(TAG, "FILE NOT COPIED");
				// 	e.printStackTrace();
				// }
			}
			Log.e(BleManager.LOG_TAG, String.valueOf(eventValue));
			writeCharacteristic(ledEvent_char, eventValue);
		}
		else{
			Log.d(BleManager.LOG_TAG, "NOT CONNECTED");
		}
	}

	public void writeCharacteristic(BluetoothGattCharacteristic characteristic, byte[] value){

		Log.e(BleManager.LOG_TAG, "writeCharacteristic");

    //check mBluetoothGatt is available
    if (gatt == null) {
      Log.e(TAG, "lost connection");
    }

    if (ledService == null){
      Log.e(TAG, "service not found!");
    }

    if (characteristic == null) {
      Log.e(TAG, "char not found!");
    }

    characteristic.setValue(value);
    //boolean status = mConnGatt.writeCharacteristic(characteristic);
    Log.d(TAG, String.valueOf(value)+" writeCharacteristic-value");
    Log.d(TAG,String.valueOf(characteristic)+" writeCharacteristic-char-value");
    gatt.writeCharacteristic(characteristic);

  }

	public void requestConnectionPriority(int connectionPriority, Callback callback) {
		if (gatt == null) {
			callback.invoke("BluetoothGatt is null", null);
			return;
		}

		if (Build.VERSION.SDK_INT >= LOLLIPOP) {
			boolean status = gatt.requestConnectionPriority(connectionPriority);
			callback.invoke(null, status);
		} else {
			callback.invoke("Requesting connection priority requires at least API level 21", null);
		}
	}

	public void requestMTU(int mtu, Callback callback) {
		if (!isConnected()) {
			callback.invoke("Device is not connected", null);
			return;
		}

		if (gatt == null) {
			callback.invoke("BluetoothGatt is null", null);
			return;
		}

		if (Build.VERSION.SDK_INT >= LOLLIPOP) {
			requestMTUCallback = callback;
			gatt.requestMtu(mtu);
		} else {
			callback.invoke("Requesting MTU requires at least API level 21", null);
		}
	}

	@Override
	public void onMtuChanged(BluetoothGatt gatt, int mtu, int status) {
		super.onMtuChanged(gatt, mtu, status);
		if (requestMTUCallback != null) {
			if (status == BluetoothGatt.GATT_SUCCESS) {
				requestMTUCallback.invoke(null, mtu);
			} else {
				requestMTUCallback.invoke("Error requesting MTU status = " + status, null);
			}

			requestMTUCallback = null;
		}
	}

	// Some peripherals re-use UUIDs for multiple characteristics so we need to
	// check the properties
	// and UUID of all characteristics instead of using
	// service.getCharacteristic(characteristicUUID)
	private BluetoothGattCharacteristic findWritableCharacteristic(BluetoothGattService service,
			UUID characteristicUUID, int writeType) {
		try {
			// get write property
			int writeProperty = BluetoothGattCharacteristic.PROPERTY_WRITE;
			if (writeType == BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE) {
				writeProperty = BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE;
			}

			List<BluetoothGattCharacteristic> characteristics = service.getCharacteristics();
			for (BluetoothGattCharacteristic characteristic : characteristics) {
				if ((characteristic.getProperties() & writeProperty) != 0
						&& characteristicUUID.equals(characteristic.getUuid())) {
					return characteristic;
				}
			}

			// As a last resort, try and find ANY characteristic with this UUID, even if it
			// doesn't have the correct properties
			return service.getCharacteristic(characteristicUUID);
		} catch (Exception e) {
			Log.e(BleManager.LOG_TAG, "Error on findWritableCharacteristic", e);
			return null;
		}
	}

	private String generateHashKey(BluetoothGattCharacteristic characteristic) {
		return generateHashKey(characteristic.getService().getUuid(), characteristic);
	}

	private String generateHashKey(UUID serviceUUID, BluetoothGattCharacteristic characteristic) {
		return String.valueOf(serviceUUID) + "|" + characteristic.getUuid() + "|" + characteristic.getInstanceId();
	}

}
