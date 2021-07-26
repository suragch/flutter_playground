import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomeWidget(),
    );
  }
}

class HomeWidget extends StatefulWidget {
  const HomeWidget({Key? key}) : super(key: key);

  @override
  _HomeWidgetState createState() => _HomeWidgetState();
}

class _HomeWidgetState extends State<HomeWidget> {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      child: Text('Read YAML'),
      onPressed: () {
        //loadAsset(context);
        const country = String.fromEnvironment('country');
        const animal = String.fromEnvironment('animal');
        print(country);
        print(animal);
      },
    );
  }

  Future<void> loadAsset(BuildContext context) async {
    final yamlString = await DefaultAssetBundle.of(context)
        .loadString('assets/my_config.yaml');
    print(yamlString);
    final dynamic yamlMap = loadYaml(yamlString);
    print(yamlMap['country']);
    print(yamlMap['animal']);
  }
}

class EnvironmentConfig {
  static const SOME_VAR = String.fromEnvironment('x');
}
