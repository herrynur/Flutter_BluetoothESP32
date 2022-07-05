import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './SelectBondedDevicePage.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class MonitoringPage extends StatefulWidget {
  @override
  _ChatPage createState() => new _ChatPage();
}

class _Message {
  int whom;
  String text;

  _Message(this.whom, this.text);
}

class _ChatPage extends State<MonitoringPage> {
  static final clientID = 0;
  BluetoothConnection? connection;

  List<_Message> messages = List<_Message>.empty(growable: true);
  String _messageBuffer = '';

  final TextEditingController textEditingController =
      new TextEditingController();
  final ScrollController listScrollController = new ScrollController();

  bool isConnecting = true;
  bool get isConnected => (connection?.isConnected ?? false);
  bool isDisconnecting = false;

  String dataBT = "";

  String _address = "...";
  String _name = "...";

  String nama = "-";
  String alamat = "-";

  String sisapakan = "-";
  String node = "-";
  String time_ = "-";

  void writedata() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nameBT', nama);
    await prefs.setString('addresBT', alamat);
  }

  void readata() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      nama = prefs.getString('nameBT')!;
      alamat = prefs.getString('addresBT')!;
    });
  }

  void setBT() async {
    showModalBottomSheet(
        context: context,
        elevation: 2,
        isScrollControlled: true,
        builder: (_) => Container(
              color: Color.fromARGB(255, 0, 20, 27),
              height: 250,
              padding: EdgeInsets.only(
                top: 5,
                left: 5,
                right: 5,
                // this will prevent the soft keyboard from covering the text fields
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                children: <Widget>[
                  Container(
                    alignment: Alignment.bottomRight,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: new Padding(
                        padding: new EdgeInsets.all(10.0),
                        child: new Text(
                          "Close",
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                      title: const Text(
                        'Selected Bluetooth',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Container(
                        alignment: Alignment.topLeft,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              alignment: Alignment.topLeft,
                              padding: EdgeInsets.only(top: 5, bottom: 5),
                              child: Text(
                                "Bluetooth Name : $nama",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            Container(
                              alignment: Alignment.topLeft,
                              padding: EdgeInsets.only(top: 5, bottom: 5),
                              child: Text(
                                "Address : $alamat",
                                style: TextStyle(color: Colors.white),
                              ),
                            )
                          ],
                        ),
                      )),
                  ListTile(
                    title: ElevatedButton(
                      child: const Text('Select Bluetooth'),
                      onPressed: () async {
                        final BluetoothDevice? selectedDevice =
                            await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) {
                              return SelectBondedDevicePage(
                                  checkAvailability: false);
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
            ));
  }

  void init() {
    readata();
    BluetoothConnection.toAddress(alamat).then((_connection) {
      print('Connected to the device');
      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });

      connection!.input!.listen(_onDataReceived).onDone(() {
        if (isDisconnecting) {
          print('Disconnecting locally!');
          setState(() {
            isConnecting = true;
          });
        } else {
          print('Disconnected remotely!');
          setState(() {
            isConnecting = true;
          });
        }
        if (this.mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      print('Cannot connect, exception occured');
      print(error);
    });
  }

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _cekitems = [];
  final _shoppingBox = Hive.box('nodeDB');
  bool ada = false;

  @override
  void initState() {
    super.initState();
    readata();
    _refreshItems();
    print("alamat : $alamat");
    print("nama : $nama");
  }

  void _refreshItems() {
    final data = _shoppingBox.keys.map((key) {
      final value = _shoppingBox.get(key);
      return {
        "key": key,
        "nodeid": value["nodeid"],
        "sisapakan": value['sisapakan'],
        "time": value['time']
      };
    }).toList();

    setState(() {
      _items = data.reversed.toList();
    });
  }

  void _checkItem(String cek) {
    final data = _shoppingBox.keys.map((key) {
      final value = _shoppingBox.get(key);
      return {
        "nodeid": value["nodeid"],
      };
    }).toList();

    setState(() {
      _cekitems = data.reversed.toList();
    });
    for (int a = 0; a < _cekitems.length; a++) {
      print(_cekitems[a].values.single);
      if (cek == _cekitems[a].values.single) {
        ada = true;
      } else {
        ada = false;
      }
    }
  }

  Future<void> _createItem(Map<String, dynamic> newItem) async {
    await _shoppingBox.add(newItem);
    _refreshItems();
  }

  Map<String, dynamic> _readItem(int key) {
    final item = _shoppingBox.get(key);
    return item;
  }

  Future<void> _updateItem(int itemKey, Map<String, dynamic> item) async {
    await _shoppingBox.put(itemKey, item);
    _refreshItems();
  }

  // Delete a single item
  Future<void> _deleteItem(int itemKey) async {
    await _shoppingBox.delete(itemKey);
    _refreshItems();
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An item has been deleted')));
  }

  @override
  void dispose() {
    // Avoid memory leak (`setState` after dispose) and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection?.dispose();
      connection = null;
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serverName = nama ?? "Unknown";
    return Scaffold(
        backgroundColor: const Color.fromARGB(255, 0, 20, 27),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            FloatingActionButton(
              onPressed: () async {
                _sendMessage("b");
                final snackBar = SnackBar(
                  content: const Text('Broadcast Send'),
                );
                ScaffoldMessenger.of(context).showSnackBar(snackBar);
              },
              backgroundColor: Colors.blue,
              child: Icon(Icons.broadcast_on_home),
            ),
            SizedBox(
              height: 10,
            ),
            FloatingActionButton(
              onPressed: () async {
                setBT();
              },
              backgroundColor: Colors.purple,
              child: Icon(Icons.bluetooth),
            ),
          ],
        ),
        appBar: AppBar(
            actions: <Widget>[
              if (isConnecting)
                IconButton(
                  icon: Icon(
                    Icons.bluetooth_disabled,
                    color: Colors.red,
                  ),
                  onPressed: () {
                    init();
                  },
                ),
              if (!isConnecting)
                IconButton(
                  icon: Icon(
                    Icons.bluetooth_audio_sharp,
                    color: Colors.green,
                  ),
                  onPressed: () {},
                ),
              IconButton(
                icon: Icon(
                  Icons.notification_add,
                  color: Colors.green,
                ),
                onPressed: () {},
              )
            ],
            backgroundColor: const Color.fromARGB(255, 0, 20, 27),
            title: (isConnecting
                ? Text(
                    'Bluetooth Disconnect',
                  )
                : isConnected
                    ? Text(serverName + " Connected")
                    : Text('Chat log with ' + serverName))),
        body: _items.isEmpty
            ? Container(
                alignment: Alignment.center,
                child: Text("No data",
                    style: TextStyle(color: Colors.white, fontSize: 26)))
            : Container(
                height: 400,
                child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, index) {
                      final currentItem = _items[index];
                      return Card(
                        color: Color.fromARGB(255, 11, 31, 39),
                        child: Container(
                          alignment: Alignment.topLeft,
                          margin: EdgeInsets.all(10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Container(
                                    alignment: Alignment.topLeft,
                                    padding: EdgeInsets.all(10),
                                    child: Text(
                                      "Node :  ${currentItem['nodeid']}",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18),
                                    ),
                                  ),
                                  Container(
                                    alignment: Alignment.topRight,
                                    child: IconButton(
                                      alignment: Alignment.topLeft,
                                      onPressed: () {
                                        _deleteItem(currentItem['key']);
                                      },
                                      icon: Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                              Container(
                                width: 300,
                                height: 1,
                                color: Colors.white,
                              ),
                              Container(
                                alignment: Alignment.topLeft,
                                padding: EdgeInsets.all(10),
                                child: Text(
                                  "Sisa Pakan : ${currentItem['sisapakan'].toString()} gr",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 16),
                                ),
                              ),
                              Container(
                                alignment: Alignment.topLeft,
                                padding: EdgeInsets.all(10),
                                child: Text(
                                  "Time : ${currentItem['time'].toString()} ",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
              ));
  }

  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    // Apply backspace control character
    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }

    // Create message if there is new line character
    String dataString = String.fromCharCodes(buffer);
    int index = buffer.indexOf(13);
    if (~index != 0) {
      setState(() {
        messages.add(
          _Message(
            1,
            backspacesCounter > 0
                ? _messageBuffer.substring(
                    0, _messageBuffer.length - backspacesCounter)
                : _messageBuffer + dataString.substring(0, index),
          ),
        );
        _messageBuffer = dataString.substring(index);
        //print("message buffer if = ${dataString}");
      });
    } else {
      _messageBuffer = (backspacesCounter > 0
          ? _messageBuffer.substring(
              0, _messageBuffer.length - backspacesCounter)
          : _messageBuffer + dataString);
      //print("message buffer else = ${dataString}");
      setState(() {
        dataBT = dataString;
        print("Data BT = $dataBT");
        List<String> result = dataBT.split(',');
        sisapakan = result[2];
        node = result[1];
        time_ = DateTime.now().toString();
      });
      _checkItem(node);
      if (ada == false) {
        print("masuk false");
        _shoppingBox.put(int.parse(node),
            {"nodeid": node, "sisapakan": sisapakan, "time": DateTime.now()});
        _refreshItems();
      } else if (ada == true) {
        print("masuk true");
        _shoppingBox.put(int.parse(node),
            {"nodeid": node, "sisapakan": sisapakan, "time": DateTime.now()});
        _refreshItems();
      }
    }
  }

  void _sendMessage(String text) async {
    text = text.trim();
    textEditingController.clear();

    if (text.length > 0) {
      try {
        connection!.output.add(Uint8List.fromList(utf8.encode(text + "\r\n")));
        await connection!.output.allSent;

        setState(() {
          messages.add(_Message(clientID, text));
        });

        Future.delayed(Duration(milliseconds: 333)).then((_) {
          listScrollController.animateTo(
              listScrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 333),
              curve: Curves.easeOut);
        });
      } catch (e) {
        // Ignore error, but notify state
        setState(() {});
      }
    }
  }
}
