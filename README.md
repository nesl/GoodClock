# GoodClock: Providing Shared Notion of Time across Smartphones

An application-level library based on the NTP with the goal to provide the shared notion of time across smartphones. GoodClock allows drift correction in cases where the NTP updates are not available frequently. 


# 1. Android implementation
- GoodClock library implementation for android is provided in the repo folder *Android_Library*.
- A sample Android application is included in the repo folder *Android_Example*.
- GoodClock Android library and the sample Android application are authored by [Sandeep Singh Sandha](https://sites.google.com/view/sandeep-/home). For any questions/clarifications feel free to drop an email.
- The Android implementation can be used to timestamp the sensor data, generate or listen to common events across Smartphones.


## 1.1 Android usage
The classes *SntpDsense* and *GoodClock* can be included in any application written for Android and their respective functions can be used as follows in three simple steps:
1. Create GoodClock object.
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

goodClock.Now() can be used to timestamp the sensor data, network events and other actions.
```

## 1.2 Changing default parameters
GoodClock Android library has parameters which may work for most of the user needs, but for specific applications the parameters can be changed. More details of the parameters will be added. Some of the important parameters are as follows:
- ntpHost: can be updated to the preferred NTP server. Currently, it uses Apple NTP server.
- drift: is disabled by default. This can be set to 1.
- retry: currently for each offset calcuations, 10 NTP requests are made to account for NTP variability.
- period: NTP offset calculations are done in the background periodically every 15 minutes. This can be changed to more frequent updates based on application constraints.

## 1.3 Accuracy of Android implementation
The Android implementation which calculates the offset using NTP server was tested across a set of Android Smartphones using the UCLA Campus Wifi Network. The variability of offset calculations was within 1 millisecond for 95% of the cases. More details are available in the [paper and the offset variability testing repository](https://github.com/nesl/Time-Sync-Across-Smartphones).
