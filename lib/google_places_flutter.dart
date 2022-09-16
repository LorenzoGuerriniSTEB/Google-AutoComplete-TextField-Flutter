library google_places_flutter;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import 'package:google_places_flutter/model/place_details.dart';
import 'package:google_places_flutter/model/prediction.dart';

class GooglePlaceAutoCompleteTextField extends StatefulWidget {
  final InputDecoration inputDecoration;
  final ItemClick? itmClick;
  final GetPlaceDetailswWithLatLng? getPlaceDetailWithLatLng;
  final bool isLatLngRequired;

  final TextStyle? textStyle;
  final String googleAPIKey;
  final int debounceTime;
  final List<String> countries;
  final TextEditingController? textEditingController;

  final String? languageCode;

  final double? latitude;
  final double? longitude;

  ///Defaulta is 20Km
  final double? radius;

  ///Defaulta is false
  final bool? showParkingOnlyInRadius;

  const GooglePlaceAutoCompleteTextField({
    Key? key,
    required this.inputDecoration,
    this.itmClick,
    this.getPlaceDetailWithLatLng,
    this.isLatLngRequired = true,
    this.textStyle,
    required this.googleAPIKey,
    this.debounceTime = 600,
    this.countries = const [],
    this.textEditingController,
    this.languageCode,
    this.latitude,
    this.longitude,
    this.radius,
    this.showParkingOnlyInRadius,
  }) : super(key: key);

  @override
  _GooglePlaceAutoCompleteTextFieldState createState() =>
      _GooglePlaceAutoCompleteTextFieldState();
}

class _GooglePlaceAutoCompleteTextFieldState
    extends State<GooglePlaceAutoCompleteTextField> {
  final subject = PublishSubject<String>();
  OverlayEntry? _overlayEntry;
  List<Prediction> alPredictions = [];

  TextEditingController controller = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  bool isSearched = false;

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        decoration: widget.inputDecoration,
        style: widget.textStyle,
        controller: widget.textEditingController,
        onChanged: (string) => (subject.add(string)),
      ),
    );
  }

  getLocation(String text) async {
    Dio dio = Dio();
    String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$text&key=${widget.googleAPIKey}';

    //Country
    if (widget.countries.isNotEmpty) {
      for (int i = 0; i < widget.countries.length; i++) {
        String country = widget.countries[i];

        if (i == 0) {
          url += '&components=country:$country';
        } else {
          url += '|country:$country';
        }
      }
    }

    //Language
    if (widget.languageCode != null) {
      url += '&language=${widget.languageCode}';
    }

    //Positions
    if (widget.latitude != null && widget.longitude != null) {
      url += '&location=${widget.latitude}%2C${widget.longitude}';
      url += '&radius=${widget.radius ?? 20000}';
      if (widget.showParkingOnlyInRadius ?? false) {
        url += '&strictbounds=true';
      }
    }

    Response response = await dio.get(url);
    PlacesAutocompleteResponse subscriptionResponse =
        PlacesAutocompleteResponse.fromJson(response.data);

    if (text.isEmpty) {
      alPredictions.clear();
      _overlayEntry!.remove();
      return;
    }

    isSearched = false;
    if (subscriptionResponse.predictions!.isNotEmpty) {
      alPredictions.clear();
      alPredictions.addAll(subscriptionResponse.predictions!);
    }

    //if (this._overlayEntry == null)

    _overlayEntry = null;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context)!.insert(_overlayEntry!);
    //   this._overlayEntry.markNeedsBuild();
  }

  @override
  void initState() {
    super.initState();
    subject.stream
        .distinct()
        .debounceTime(Duration(milliseconds: widget.debounceTime))
        .listen(textChanged);
  }

  textChanged(String text) async {
    getLocation(text);
  }

  OverlayEntry? _createOverlayEntry() {
    if (mounted && context.findRenderObject() != null) {
      RenderBox renderBox = context.findRenderObject() as RenderBox;
      var size = renderBox.size;
      var offset = renderBox.localToGlobal(Offset.zero);
      return OverlayEntry(
          builder: (context) => Positioned(
                left: offset.dx,
                top: size.height + offset.dy,
                width: size.width,
                child: CompositedTransformFollower(
                  showWhenUnlinked: false,
                  link: _layerLink,
                  offset: Offset(0.0, size.height + 5.0),
                  child: Material(
                      elevation: 1.0,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: alPredictions.length,
                        itemBuilder: (BuildContext context, int index) {
                          return InkWell(
                            onTap: () {
                              if (index < alPredictions.length) {
                                widget.itmClick!(alPredictions[index]);
                                if (!widget.isLatLngRequired) return;

                                getPlaceDetailsFromPlaceId(
                                    alPredictions[index]);

                                removeOverlay();
                              }
                            },
                            child: Container(
                                padding: const EdgeInsets.all(10),
                                child: Text(alPredictions[index].description!)),
                          );
                        },
                      )),
                ),
              ));
    }
    return null;
  }

  removeOverlay() {
    alPredictions.clear();
    _overlayEntry = _createOverlayEntry();
    if (mounted) {
      Overlay.of(context)!.insert(_overlayEntry!);
      _overlayEntry!.markNeedsBuild();
    }
  }

  Future<void> getPlaceDetailsFromPlaceId(Prediction prediction) async {
    //String key = GlobalConfiguration().getString('google_maps_key');
    var url =
        'https://maps.googleapis.com/maps/api/place/details/json?placeid=${prediction.placeId}&key=${widget.googleAPIKey}';
    Response response = await Dio().get(
      url,
    );

    PlaceDetails placeDetails = PlaceDetails.fromJson(response.data);

    prediction.lat = placeDetails.result!.geometry!.location!.lat.toString();
    prediction.lng = placeDetails.result!.geometry!.location!.lng.toString();

    widget.getPlaceDetailWithLatLng!(prediction);

    // prediction.latLng = new LatLng(placeDetails.result.geometry.location.lat,
    //     placeDetails.result.geometry.location.lng);
  }
}

PlacesAutocompleteResponse parseResponse(Map responseBody) {
  return PlacesAutocompleteResponse.fromJson(
      responseBody as Map<String, dynamic>);
}

PlaceDetails parsePlaceDetailMap(Map responseBody) {
  return PlaceDetails.fromJson(responseBody as Map<String, dynamic>);
}

typedef ItemClick = void Function(Prediction postalCodeResponse);
typedef GetPlaceDetailswWithLatLng = void Function(
    Prediction postalCodeResponse);
