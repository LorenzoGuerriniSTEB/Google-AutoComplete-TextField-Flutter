library example;

import 'package:flutter/material.dart';

import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Custom Autocomplete sample'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;

  const MyHomePage({
    super.key,
    required this.title,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 20),
            placesAutoCompleteTextField(),
          ],
        ),
      ),
    );
  }

  Container placesAutoCompleteTextField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GooglePlaceAutoCompleteTextField(
          textEditingController: controller,
          googleAPIKey: 'YOUR_GOOGLE_API_KEY',
          inputDecoration:
              const InputDecoration(hintText: 'Search your location'),
          debounceTime: 800,
          countries: const <String>['in', 'fr'],
          getPlaceDetailWithLatLng: (Prediction prediction) {
            print('placeDetails${prediction.lng}');
          },
          itmClick: (Prediction prediction) {
            controller.text = prediction.description ?? '';

            controller.selection = TextSelection.fromPosition(
                TextPosition(offset: prediction.description?.length ?? 0));
          }),
    );
  }
}
