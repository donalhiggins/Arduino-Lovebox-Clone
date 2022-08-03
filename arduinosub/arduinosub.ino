#include <ArduinoMqttClient.h>
#include <WiFiNINA.h>
#include <stdlib.h>
#include "arduino_secrets.h"
#include "bitmaps.h"
// Screen dimensions
#define SCREEN_WIDTH  128
#define SCREEN_HEIGHT 128 // Change this to 96 for 1.27" OLED.

// You can use any (4 or) 5 pins 
#define SCLK_PIN 13
#define MOSI_PIN 11
#define DC_PIN   7
#define CS_PIN   10
#define RST_PIN  8

// Color definitions
#define BLACK           0x0000
#define BLUE            0x001F
#define RED             0xD000
#define GREEN           0x07E0
#define CYAN            0x07FF
#define MAGENTA         0xF81F
#define YELLOW          0xFFE0  
#define WHITE           0xFFFF
#define GRAY            0x7BEF
#define PINK            0xFC5A
#define BROWN           0x6A00

#include <Adafruit_GFX.h>
#include <Adafruit_SSD1351.h>
#include <SPI.h>
#include <string>

Adafruit_SSD1351 tft = Adafruit_SSD1351(SCREEN_WIDTH, SCREEN_HEIGHT, CS_PIN, DC_PIN, MOSI_PIN, SCLK_PIN, RST_PIN);  


///////please enter your sensitive data in the Secret tab/arduino_secrets.h
char ssid[] = SECRET_SSID;        // your network SSID
char pass[] = SECRET_PASS;    // your network password

// For photoresistor
int sensorValue = 0;

bool isMessage = false;
bool isTimer = false;
bool change = false;
bool isPic = false;
bool fullMessage = false;

// Set up timer for message
int messageDisplayTime = 0;
String message;
String identifier;

WiFiClient wifiClient;
MqttClient mqttClient(wifiClient);

const char broker[] = "broker.emqx.io";
int        port     = 1883;
const char topic[]  = "";

void setup() {
  // Set up photoresistor sensor input
  pinMode(A0, INPUT);

  // Set up pin for motor
  pinMode(3, OUTPUT);
  // Initialize serial and wait for port to open:
  // Not entirely sure how to keep serial when not connected to computer so I commented out when I don't need it 
  
  Serial.begin(9600);
  while (!Serial) {
    ; // wait for serial port to connect. Needed for native USB port only
  }
  
  // Initalize screen
  tft.begin();
  tft.fillRect(0, 0, 128, 128, BLACK);

  // attempt to connect to Wifi network:
  testdrawtext("Connecting to WIFI", WHITE);
  // 
  // Serial.print("Attempting to connect to SSID: ");
  // Serial.println(ssid);
  while (WiFi.begin(ssid, pass) != WL_CONNECTED) {
    // failed, retry
    // Serial.print(".");
    delay(5000);
  }
  // Wifi connected
  tft.fillScreen(BLACK);
  testdrawtext("WIFI Connected", WHITE);
  delay(400);
  //Serial.println("You're connected to the network");
  //Serial.println();


  // Connect to MQTT Broker
  //Serial.print("Attempting to connect to the MQTT broker: ");
  //Serial.println(broker);
  tft.fillScreen(BLACK);
  testdrawtext("Connecting to MQTT Broker", WHITE);

  if (!mqttClient.connect(broker, port)) {
    //Serial.print("MQTT connection failed! Error code = ");
    //Serial.println(mqttClient.connectError());

    while (1);
  }

  // MQTT Broker connected
  //Serial.println("You're connected to the MQTT broker!");
  tft.fillScreen(BLACK);
  testdrawtext("MQTT Connected", WHITE);
  delay(400);

  // set the message receive callback
  mqttClient.onMessage(onMqttMessage);

  //Serial.print("Subscribing to topic: ");
  //Serial.println(topic);

  // subscribe to a topic
  mqttClient.subscribe(topic);


  // topics can be unsubscribed using:
  // mqttClient.unsubscribe(topic);

  //Serial.print("Topic: ");
  //Serial.println(topic);

  // Clear screen after setup
  tft.fillScreen(BLACK);
  
}

void loop() {
  // call poll() regularly to allow the library to receive MQTT messages and
  // send MQTT keep alive which avoids being disconnected by the broker
  mqttClient.poll();
  sensorValue = analogRead(A0);
  if(isMessage){
      if(sensorValue <= 30){
        change = false;
        digitalWrite(3, 0);
        // Draw turtle on screen to indicate that there is a message
        tft.fillScreen(BLACK);
        tft.drawBitmap(16, 16, turtleBody, 96, 96, GREEN);
        tft.drawBitmap(16, 16, turtleShell, 96, 96, BROWN);
        tft.drawBitmap(16, 16, turtleEyeWhite, 96, 96, WHITE);
        tft.drawBitmap(16, 16, turtleEye, 96, 96, BLACK);
        delay(2000);
        // Check if we have an image or a message based upon identifier
        if(identifier.equals("$&#")){
          testdrawtext(message.substring(0, message.length() - 3), WHITE);
        }
        else {
          
          if(fullMessage) {
            drawImage(message);
            isPic = false;
            fullMessage = false;
          }
          
        }

        
        isMessage = false;
   
        // Start timer for message
        isTimer = true;
        messageDisplayTime = 0;
      }
      else{
        digitalWrite(3, 255);
      }
  }
  if(isTimer){
    // Stop the program for ten seconds to display the message
    delay(10000);

    isTimer = false;
  }
  sensorValue = analogRead(A0);
  if(!isMessage){
    if(sensorValue <= 30){
      if(!change){
        // If box is opened but we don't have a message display the koala graphic
        tft.fillScreen(BLACK);
        tft.drawBitmap(16, 16, koala, 96, 96, GRAY);
        tft.drawBitmap(16, 16, ears, 96, 96, PINK);
        drawText("I love you :)", WHITE, 25, 100);
        change = true;
      }
      
    }
    else{
      delay(1500);
      sensorValue = analogRead(A0);
      // If box is closed turn screen off
      if(sensorValue > 30){
        change = false;
        tft.fillScreen(BLACK);
      }
    }
  }
}

void onMqttMessage(int messageSize) {
  String msg = "";
  // we received a message, print out the topic and contents

  /*
  Serial.println("Received a message with topic '");
  Serial.print(mqttClient.messageTopic());
  Serial.print("', length ");
  Serial.print(messageSize);
  Serial.println(" bytes:");
  Serial.println(freeMemory());
  */
  // use the Stream interface to print the contents
  while (mqttClient.available()) {
    Serial.println(freeMemory());
    Serial.println(msg.length());
    msg += (char)mqttClient.read();
  }
  isMessage = true;

  if(isPic){
    message = message.substring(0, message.length()-1) + msg;
    fullMessage = true;
  }
  else{
    message = msg;
  }
  if(msg.charAt(msg.length()-1) == '$'){
    isPic = true;
    isMessage = false;
  }
  

  identifier = message.substring((message.length()) - 3);

}


void testdrawtext(String text, uint16_t color) {
  tft.fillScreen(BLACK);
  tft.setCursor(0,0);
  tft.setTextColor(color);
  tft.print(text);
}

void drawText(String text, uint16_t color, int x, int y) {
  tft.setCursor(x, y);
  tft.setTextColor(color);
  tft.print(text);
}

void drawImage(String msg) {
  tft.fillScreen(BLACK);
  String tmp;
  int tc = 0;
  int cnt = 0;
  int x = 0;
  int y = 0;
  int sx = 128;
  int sy = 128;
  
  for(int Y = 0; Y < sy; Y++){
     for(int X = 0; X < sx; X++){
        if(tc >= cnt){
          tmp = unpack(msg);
          cnt = tmp.length();
          tc = 0;
          msg = msg.substring(msg.indexOf(",") + 1);
        }
        if(tmp.charAt(tc) == '0'){
          tft.drawPixel(X+x, Y+y, WHITE);
        }
        
      if(tc < (sx*sy)) tc++;
     }
 }
}

String unpack(String rle) {
  // 1:3
  String output = "";
  for(int i = 0; i < rle.substring(1 + rle.indexOf(":")).toInt(); i++){
    output += rle.substring(0, rle.indexOf(":"));
  }
  return output;
 }



#ifdef __arm__
// should use uinstd.h to define sbrk but Due causes a conflict
extern "C" char* sbrk(int incr);
#else  // __ARM__
extern char *__brkval;
#endif  // __arm__

int freeMemory() {
  char top;
#ifdef __arm__
  return &top - reinterpret_cast<char*>(sbrk(0));
#elif defined(CORE_TEENSY) || (ARDUINO > 103 && ARDUINO != 151)
  return &top - __brkval;
#else  // __arm__
  return __brkval ? &top - __brkval : &top - __malloc_heap_start;
#endif  // __arm__
}
