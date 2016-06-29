/*
 * BeamsBeats
 * Cyrille Martraire 2009-2012
 * 
 * Reads 4 analog inputs (LDR sensing laser beams)
 * When each analog input exceeds a threshold, send a MIDI note on velocity 127.
 */

// BEAMS DETECTION
int _offsetFromMax = 10;
int _thresholdOffset = 5;
int _debounceDelayMs = 60;

// BY CHANNEL
int movingMaxSum[6];
int movingMax[6];
int movingMinSum[6];
int movingMin[6];

int movingMid[6];

long lastTime[6];
boolean prevState[6];

//midiClock
int quarterNumber = 4;
long lastTick;// ms
int midiClockPeriod = 42;// ms
long lastMidiClock;

//MIDI settings
int channel = 0x90;
int velocity = 127;
int notes[] = {37, 36, 42, 82, 40, 38}; // PAD 1-6 in order:  {37, 36, 42, 82, 40, 38}
int n=6;//number of analog inputs
int cursor = 0;

// DEBUG
int ledPin = 13;   // select the pin for the LED
boolean debug = false;

void setup() {
  pinMode(ledPin, OUTPUT);  // declare the ledPin as an OUTPUT
  
  //  Set MIDI baud rate:
  Serial.begin(31250);
  if(debug){
      Serial.begin(19200);
      Serial.print("Starting");
  }
  
  lastTick = millis();// ms
}

/**
 * Main routine
 */
boolean detect(int x, long timeMs) {
	if (isClipping(x)) {
		return false;
	}
	adaptativeMinMax(x);
        if(debug){printDebug(x);}
	boolean detection = x < movingMid[cursor];
	return debouncedDetection(detection, timeMs);
}

// check for clipping
boolean isClipping(int x) {
	return x <= 1 || x >= 1023;
}

// computes moving min and max (approximated) to cope with sudden change
// of sensors and light conditions at anytime
// http://www.daycounter.com/LabBook/Moving-Average.phtml
void adaptativeMinMax(int x) {
	// long-term moving average to compute the adaptative max
	movingMaxSum[cursor] = movingMaxSum[cursor] + x - (movingMaxSum[cursor] >> 4);
	movingMax[cursor] = movingMaxSum[cursor] >> 4;

	// conditional short-term moving average to compute the adaptative
	// min
	if (x < movingMax[cursor] - _offsetFromMax) {
		movingMinSum[cursor] = movingMinSum[cursor] + x - (movingMinSum[cursor] >> 2);
		movingMin[cursor] = movingMinSum[cursor] >> 2;
	}

	// adaptative threshold for actual detection
	movingMid[cursor] = (movingMin[cursor] + movingMax[cursor]) / 2;
	if (movingMid[cursor] > _thresholdOffset) {
		movingMid[cursor] -= _thresholdOffset;
	}
}

void printDebug(int x) {
        Serial.print("Reading: ");  
	Serial.print(x);
        Serial.print("\tmin: ");
        Serial.print(movingMin[cursor]);
        Serial.print("\tmax: ");
        Serial.print(movingMax[cursor]);
        Serial.print("\tmid: ");
        Serial.print(movingMid[cursor]);
        Serial.println("\t");
}

// Given a detection, make sure it is not a bounce of some prior
// detection
boolean debouncedDetection(boolean newState, long timeMs) {
	if (!newState) {
		prevState[cursor] = newState;
		return false;
	}
	if (prevState[cursor]) {
		// was already ON: same state continued
		return false;
	}
	// was not already ON but used to be less than debounceDelayMs ago
	if ((timeMs - lastTime[cursor]) < _debounceDelayMs) {
		return false;
	}
	// new status ON detected
	lastTime[cursor] = timeMs;
	prevState[cursor] = newState;
	return newState;
}

void onFullRevolution(long timeMs) {
	long revolutionPeriod = timeMs - lastTick;

	lastTick = timeMs;
	int newPeriod  = midiClockPeriodFor(revolutionPeriod, quarterNumber);
        if(newPeriod > 30) {
           newPeriod = midiClockPeriod;
        }
        midiClockPeriod = newPeriod;
        _debounceDelayMs = 6 * midiClockPeriod;
}

int midiClockPeriodFor(long revolutionPeriod, int quarterNumber) {
	return (int) (revolutionPeriod / (quarterNumber * 24));
}

void loop() {
  long timeMs = millis();
  for(cursor = 0; cursor < n; cursor = cursor+1){
    int input = cursor;
    int reading = analogRead(input);
    boolean detection = detect(reading, timeMs);
    if(detection == HIGH){
        int note = notes[input];
        if(!debug){
            noteOn(channel, note, velocity);
        }
        digitalWrite(ledPin, HIGH);  // turn the ledPin on
        if(cursor == 0){
          onFullRevolution(timeMs);
        }
    } else{
        digitalWrite(ledPin, LOW);  // turn the ledPin on
    }
  }
  if(!debug && (timeMs - lastMidiClock) > midiClockPeriod){
    midiClock();
    lastMidiClock = timeMs;//reset
  }
  delay(2);//10
}

//  plays a MIDI note.  Doesn't check to see that
//  cmd is greater than 127, or that data values are  less than 127:
void noteOn(char cmd, char data1, char data2) {
  Serial.print(cmd, BYTE);
  Serial.print(data1, BYTE);
  Serial.print(data2, BYTE);
}

// Sends a MIDI tick (expected to be 24 ticks per quarter)
void midiClock(){
  Serial.print(0xF8, BYTE);
}
