import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './SelectBondedDevicePage.dart';
import './monitoringBT.dart';

class MainPage extends StatefulWidget {
  @override
  _MainPage createState() => new _MainPage();
}

class _MainPage extends State<MainPage> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;

  String _address = "...";
  String _name = "...";

  String nama = "-";
  String alamat = "-";

  Timer? _discoverableTimeoutTimer;
  int _discoverableTimeoutSecondsLeft = 0;
  bool _autoAcceptPairingRequests = false;

  void writedata() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nameBT', nama);
    await prefs.setString('addresBT', alamat);
  }

  void readata() async {
    final prefs = await SharedPreferences.getInstance();
    nama = prefs.getString('nameBT')!;
    alamat = prefs.getString('addresBT')!;
  }

  @override
  void initState() {
    super.initState();

    // Get current state
    readata();
    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    Future.doWhile(() async {
      // Wait if adapter not enabled
      if ((await FlutterBluetoothSerial.instance.isEnabled) ?? false) {
        return false;
      }
      await Future.delayed(Duration(milliseconds: 0xDD));
      return true;
    }).then((_) {
      // Update the address field
      FlutterBluetoothSerial.instance.address.then((address) {
        setState(() {
          _address = address!;
        });
      });
    });

    FlutterBluetoothSerial.instance.name.then((name) {
      setState(() {
        _name = name!;
      });
    });

    // Listen for futher state changes
    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;

        // Discoverable mode is disabled when Bluetooth gets disabled
        _discoverableTimeoutTimer = null;
        _discoverableTimeoutSecondsLeft = 0;
      });
    });
  }

  @override
  void dispose() {
    FlutterBluetoothSerial.instance.setPairingRequestHandler(null);
    _discoverableTimeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final BluetoothDevice? selectedDevice =
              await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) {
                return SelectBondedDevicePage(checkAvailability: false);
              },
            ),
          );

          if (selectedDevice != null) {
            print(selectedDevice.address);
            print(selectedDevice.name);
            setState(() {
              nama = selectedDevice.name!;
              alamat = selectedDevice.address;
              writedata();
            });
          } else {
            print('Connect -> no device selected');
          }
        },
        backgroundColor: Colors.green,
        child: Icon(Icons.bluetooth),
      ),
      appBar: AppBar(
        title: const Text('BT test'),
      ),
      body: Container(
        child: ListView(
          children: <Widget>[
            SwitchListTile(
              title: const Text('Enable Bluetooth'),
              value: _bluetoothState.isEnabled,
              onChanged: (bool value) {
                // Do the request and update with the true value then
                future() async {
                  // async lambda seems to not working
                  if (value)
                    await FlutterBluetoothSerial.instance.requestEnable();
                  else
                    await FlutterBluetoothSerial.instance.requestDisable();
                }

                future().then((_) {
                  setState(() {});
                });
              },
            ),
            ListTile(
                title: const Text('Selected Bluetooth'),
                subtitle: Container(
                  alignment: Alignment.topLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        alignment: Alignment.topLeft,
                        padding: EdgeInsets.all(5),
                        child: Text("Bluetooth Name : $nama"),
                      ),
                      Container(
                        alignment: Alignment.topLeft,
                        padding: EdgeInsets.all(5),
                        child: Text("Address : $alamat"),
                      )
                    ],
                  ),
                )),
            Divider(),
            ListTile(
              title: ElevatedButton(
                child: const Text('Monitoring data'),
                onPressed: () async {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) {
                        return MonitoringPage();
                      },
                    ),
                  );
                },
              ),
            ),
            ListTile(
              title: ElevatedButton(
                child: const Text('Select Bluetooth'),
                onPressed: () async {
                  final BluetoothDevice? selectedDevice =
                      await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) {
                        return SelectBondedDevicePage(checkAvailability: false);
                      },
                    ),
                  );

                  if (selectedDevice != null) {
                    print(selectedDevice.address);
                    print(selectedDevice.name);
                    setState(() {
                      nama = selectedDevice.name!;
                      alamat = selectedDevice.address;
                      writedata();
                    });
                  } else {
                    print('Connect -> no device selected');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
