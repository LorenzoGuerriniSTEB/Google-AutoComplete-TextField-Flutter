library google_places_flutter;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import 'model/place_details.dart';
import 'model/prediction.dart';

class GooglePlaceAutoCompleteTextField extends StatefulWidget {
  final InputDecoration inputDecoration;
  final ItemClick? itmClick;
  final GetPlaceDetailswWithLatLng? getPlaceDetailWithLatLng;
  final bool isLatLngRequired;

  final Error? onError;

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
    this.onError,
    this.textStyle,
    required this.googleAPIKey,
    this.debounceTime = 600,
    this.countries = const <String>[],
    this.textEditingController,
    this.languageCode,
    this.latitude,
    this.longitude,
    this.radius,
    this.showParkingOnlyInRadius,
  }) : super(key: key);

  @override
  State<GooglePlaceAutoCompleteTextField> createState() =>
      _GooglePlaceAutoCompleteTextFieldState();
}

class _GooglePlaceAutoCompleteTextFieldState
    extends State<GooglePlaceAutoCompleteTextField> {
  final PublishSubject<String> subject = PublishSubject<String>();
  OverlayEntry? _overlayEntry;
  List<Prediction> alPredictions = <Prediction>[];

  TextEditingController controller = TextEditingController();
  final LayerLink _layerLink = LayerLink();

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        decoration: widget.inputDecoration,
        style: widget.textStyle,
        controller: widget.textEditingController,
        onChanged: (String string) => subject.add(string),
      ),
    );
  }

  Future<void> getLocation(String text) async {
    final Dio dio = Dio();
    String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$text&key=${widget.googleAPIKey}';

    //Country
    if (widget.countries.isNotEmpty) {
      for (int i = 0; i < widget.countries.length; i++) {
        final String country = widget.countries[i];

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

    if (text.isEmpty) {
      alPredictions.clear();
      _overlayEntry?.remove();
      return;
    }

    try {
      final Response<dynamic> response = await dio.get(url);
      final PlacesAutocompleteResponse subscriptionResponse =
          PlacesAutocompleteResponse.fromMap(response.data);
      if (subscriptionResponse.status == 'REQUEST_DENIED' ||
          (subscriptionResponse.errorMessage?.isNotEmpty ?? false) == true) {
        alPredictions.clear();
        _overlayEntry?.remove();
        widget.onError?.call(subscriptionResponse);
      } else {
        if (subscriptionResponse.predictions!.isNotEmpty) {
          alPredictions.clear();
          alPredictions.addAll(subscriptionResponse.predictions!);
        }

        _overlayEntry = null;
        _overlayEntry = _createOverlayEntry();
        Overlay.of(context).insert(_overlayEntry!);
      }
    } catch (e) {
      alPredictions.clear();
      _overlayEntry?.remove();
      widget.onError?.call(
        PlacesAutocompleteResponse(
          status: 'REQUEST_DENIED',
          errorMessage: e.toString(),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    subject.stream
        .distinct()
        .debounceTime(Duration(milliseconds: widget.debounceTime))
        .listen(textChanged);
  }

  Future<void> textChanged(String text) async => getLocation(text);

  OverlayEntry? _createOverlayEntry() {
    if (mounted && context.findRenderObject() != null) {
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final Size size = renderBox.size;
      final Offset offset = renderBox.localToGlobal(Offset.zero);
      return OverlayEntry(
          builder: (BuildContext context) => Positioned(
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
                                if (!widget.isLatLngRequired) {
                                  return;
                                }

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

  void removeOverlay() {
    alPredictions.clear();
    _overlayEntry = _createOverlayEntry();
    if (mounted) {
      Overlay.of(context).insert(_overlayEntry!);
      _overlayEntry!.markNeedsBuild();
    }
  }

  Future<void> getPlaceDetailsFromPlaceId(Prediction prediction) async {
    //String key = GlobalConfiguration().getString('google_maps_key');
    final String url =
        'https://maps.googleapis.com/maps/api/place/details/json?placeid=${prediction.placeId}&key=${widget.googleAPIKey}';
    final Response<dynamic> response = await Dio().get(
      url,
    );

    final PlaceDetails placeDetails = PlaceDetails.fromJson(response.data);

    prediction.lat = placeDetails.result!.geometry!.location!.lat.toString();
    prediction.lng = placeDetails.result!.geometry!.location!.lng.toString();

    widget.getPlaceDetailWithLatLng!(prediction);

    // prediction.latLng = new LatLng(placeDetails.result.geometry.location.lat,
    //     placeDetails.result.geometry.location.lng);
  }
}

PlacesAutocompleteResponse parseResponse(Map<String, dynamic> responseBody) {
  return PlacesAutocompleteResponse.fromMap(responseBody);
}

PlaceDetails parsePlaceDetailMap(Map<String, dynamic> responseBody) {
  return PlaceDetails.fromJson(responseBody);
}

typedef ItemClick = void Function(Prediction postalCodeResponse);
typedef GetPlaceDetailswWithLatLng = void Function(
    Prediction postalCodeResponse);
typedef Error = void Function(PlacesAutocompleteResponse response);
