# GoodClock: Providing Shared Notion of Time across Smartphones

**Paper for reference**
```
@inproceedings{sandha2020time,
  title={Time Awareness in Deep Learning-Based Multimodal Fusion Across Smartphone Platforms},
  author={Sandha, Sandeep Singh and Noor, Joseph and Anwar, Fatima M and Srivastava, Mani},
  booktitle={2020 IEEE/ACM Fifth International Conference on Internet-of-Things Design and Implementation (IoTDI)},
  pages={149--156},
  year={2020},
  organization={IEEE}
}
```

An application-level library based on the NTP to provide the shared notion of time across smartphones. GoodClock allows drift correction in cases where the NTP updates are not available frequently.  The figure below shows the GoodClock library results using UCLA campus Wi-Fi on Android devices.
![GoodClock Library Results on UCLA Wi-Fi](https://github.com/nesl/GoodClock/blob/master/Android_Library/GoodClock_Android_Wifi.png)

# 1. Android Implementation
- GoodClock library implementation for Android is provided in the repo folder *Android_Library*.
- A sample Android application is included in the repo folder *Android_Example*.
- The Android implementation can be used to timestamp the sensor data, generate or listen to common events across Smartphones.


## 1.1 Android Usage
The classes *SntpDsense* and *GoodClock* can be included in any application written for Android, and their respective functions can be used as follows in three simple steps:
1. Create a GoodClock object.
2. Start the background thread to update the GoodClock time using NTP.
3. Use the GoodClock functions to get time errors, accurate system time.

```
//1) Create GoodClock object
GoodClock goodClock = new GoodClock();;

//2. Start the background thread
goodClock.start();

//3. Using the GoodClock functions
long ntp_error = goodClock.getNtp_clockoffset();
long curr_time = goodClock.Now(); //correct system time shared across Smartphones based on NTP
```

```
goodClock.Now() is equivalent to the System.currentTimeMillis(). 
But includes the time error correction (NTP error and drift).

goodClock.Now() can be used to timestamp the sensor data, network events, and other actions.
```

## 1.2 Changing Default Parameters
GoodClock Android library has parameters that may work for most of the user needs, but for specific applications, the settings can be changed. More details of the settings will be added. Some of the critical parameters are as follows:
- ntpHost: can be updated to the preferred NTP server. Currently, it uses the Apple NTP server.
- drift: is disabled by default. This can be set to 1.
- retry: currently, for each offset calculations, 10 NTP requests are made to account for NTP variability.
- period: NTP offset calculations are done in the background periodically every 15 minutes. This can be changed to more frequent updates based on application constraints.

## 1.3 Accuracy of Android Implementation
The Android implementation, which calculates the offset using an NTP server, was tested across a set of Android Smartphones using the UCLA Campus Wi-Fi Network. The variability of offset calculations was within 1 millisecond for 95% of the cases.


# 2. iOS Implementation
The iOS implementation is also available in [GoodClock.swift](https://github.com/nesl/GoodClock/blob/master/GoodClock.swift)

# 3. Python Implementation
A Python implementation is available in [GoodClock.py](https://github.com/nesl/GoodClock/blob/master/GoodClock.py)

# 4. More Evaluations across Smartphones

## Devices
![Devices used to evaluate GoodClock on UCLA Wi-Fi](https://github.com/nesl/GoodClock/blob/master/devices.png)

## Results
![Offset calculations using GoodClock on UCLA Wi-Fi](https://github.com/nesl/GoodClock/blob/master/evaluation.png)
