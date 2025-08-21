import 'package:flutter/material.dart';
import 'package:spotikit/spotikit.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Three Buttons App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    run();
  }

  void run() async{
    await Spotikit.authenticateSpotify();
    // final token = await Spotikit.getAccessToken();
    // print("Access Token: $token");
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Three Buttons Page'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: null,
              icon: Icon(Icons.home),
              iconSize: 50,
            ),
            SizedBox(height: 20),
            IconButton(
              onPressed: null,
              icon: Icon(Icons.favorite),
              iconSize: 50,
            ),
            SizedBox(height: 20),
            IconButton(
              onPressed: null,
              icon: Icon(Icons.star),
              iconSize: 50,
            ),
          ],
        ),
      ),
    );
  }
}