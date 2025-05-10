import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ocr_provider.dart';
import 'package:camera/camera.dart';
class OCRScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OCRProvider>(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 6,
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: provider.cameraController == null
                    ? Center(child: CircularProgressIndicator())
                    : FutureBuilder(
                        future: provider.initializeControllerFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.done) {
                            return CameraPreview(provider.cameraController!);
                          } else {
                            return Center(child: CircularProgressIndicator());
                          }
                        },
                      ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.05,
                  vertical: screenHeight * 0.02,
                ),
                child: Card(
                  elevation: 3,
                  child: Padding(
                    padding: EdgeInsets.all(screenWidth * 0.04),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Container(
                          height: screenHeight * 0.1,
                          alignment: Alignment.center,
                          child: provider.isProcessing
                              ? CircularProgressIndicator()
                              : Text(
                                  'Results: ${provider.statusMessage}',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.05,
                                    fontWeight: FontWeight.bold,
                                    color: provider.statusMessage == 'True'
                                        ? Colors.green
                                        : Colors.black,
                                  ),
                                ),
                        ),
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: screenHeight * 0.07,
                          child: ElevatedButton(
                            onPressed: provider.toggleContinuousMode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: provider.isContinuousMode
                                  ? Colors.red
                                  : Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              provider.isContinuousMode ? 'STOP' : 'START',
                              style: TextStyle(
                                fontSize: screenWidth * 0.045,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
