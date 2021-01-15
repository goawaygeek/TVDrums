# TVDrums

TVDrums is a rather silly project that I wrote to teach myself some Swift.  It takes sensor data from an iOS device, detects when that device has been 'hit' by a drumstick and uses that hit notification (along with the drum associated with the device) to trigger a drum sample.  That sample can either be played locally on the device itself, or magically transported to a connected tvOS app that listens for up to seven connected devices and outputs sound and visuals as shown in this rather ridiculous video (not to ruin the surprise but the magic is really [Apple's Multipeer Connectivity](https://developer.apple.com/documentation/multipeerconnectivity))

[Video demo](https://www.youtube.com/watch?v=vOETCy7_c4Q):

[![YouTube video](http://knockyrsocksoff.com/drums/drums_web.gif)](https://www.youtube.com/watch?v=vOETCy7_c4Q)

I was always planning on cleaning up the code before releasing it but I moved on to [other projects](https://twitter.com/goawaygeek/status/1301339088381833216).  So here it is for you in all its ugly glory.  

### The set up
I'll talk mainly about the full project here using the iOS devices and the Apple TV as the drum brain.  The video demo includes seven iOS devices (one iPad, one iPad mini and five iPhones, an X, a six, a seven, and two fives - thanks to [Wandering Stan](https://github.com/wanderingstan) for the lend!  Drum wise it plays a kick, snare, floor and rack toms, crash, ride and hi-hat cymbals).  

From a usage perspective it is pretty straight forward.  You select the type of drum you want to associate with each device on screen via a button, tell it to start advertising with a switch and then hit away.  The hit detection code parses the on device sensor output, runs it through a pretty simple high pass filter and notifies of a hit when triggered conditions are met.  The hit is sent out using [MultipeerConnectivity](https://developer.apple.com/documentation/multipeerconnectivity).  The Apple TV app listens for notifications through the MultipeerConnectivity and then plays the appropriate audio sample and visual when triggered.  The visuals are CAEmitters and when the kick drum is triggered it also changed the background to a random colour.

### The Code

I'm just going to talk about key features of each class and where I borrowed most of my inspiration from for each element.  It is worth noting that I did originally write this so that it used CoreBluetooth for transmitting the drum triggers between devices but....my Apple TV is old and only supports two BTLE connections so I shifted to the MultipeerConnectivity at the end.  It didn't seem to be as responsive as the BTLE connections but I also didn't test it thoroughly.  

#### The iOS app
##### ViewController.swift
There really isn't anything super crazy in here.  It sets up all the controllers and patches everything together.  There is a segmented control that allows you to set the drum type for transmitting and there are buttons that allow you to play samples.  There are also a couple of switches that tell you whether you are acting as a drum trigger or the drum brain.  It does connect the audio engine and starts it up.  More on that later.

##### DrumMultipeer.swift
I can't remember who I have to thank for tipping me off on Multipeer Connectivity after the Core Bluetooth snafu but it was either [Stan](https://github.com/wanderingstan) or [Mark](https://github.com/aufflick).  I got my start following the code sample posted by Ralf Ebert [here](https://www.ralfebert.de/ios/tutorials/multipeer-connectivity/).  I have a note that the use of messages were too slow so I updated it to use the stream functionality which I took from [this gist](https://gist.github.com/lucasecf/bde1d9bd3492f29b7534).  I don't remember there being too many difficulties with this, in fact it was probably a lot easier than I thought it would be. I did cheat a bit here in that I didn't both to give each device a unique name as I'm not technically connecting to multiple peers, I'm using much more of a client server setup and multipeer connectivity just seemed to be the easiest way to achieve that.

##### DrummerAudioEngine.swift
Back when I would have considered myself a more regular software developer I worked on [some great audio software](http://www.audiomulch.com) and not to sound like too much an old man on a soapbox but writing audio software back in the day was difficult!  The work Apple have done on making a friendly audio engine is AMAZING!  Go and watch the WWDC videos from [2017](https://developer.apple.com/videos/play/wwdc2017/501/) and [2019](https://developer.apple.com/videos/play/wwdc2019/510/).  I based my code largely on [this snippet on StackOverflow](https://stackoverflow.com/questions/24383080/realtime-audio-with-avaudioengine?rq=1).  The really big problem I had was getting the drums to play over the top of each other.  I solved this by loading each sample into its own buffer connecting them to a node on the engine and then holding a reference to that inside the drumkit array.  When I wanted to play the drum I just loaded that buffer into the engine and...presto, endless drums!  It all happens inside the loadKit function but the key lines to load them are:
```
let audioPlayerNode = (AVAudioPlayerNode())
audioEngine.attach(audioPlayerNode)
audioEngine.connect(audioPlayerNode, to:environmentalNode, format: audioBuffer.format)
            
// attach the playernode and buffer to the drumkit dictionary
drumkit[percussiveInstrument.type] = drumDetails(playerNode:
audioPlayerNode, bufferNode: audioBuffer)
```

And to trigger them you then do this:
```
// stop the player
drumkit[percussiveInstrument.type]!.playerNode.stop()

// schedule the buffer
drumkit[percussiveInstrument.type]?.playerNode.scheduleBuffer(drumkit[percussiveInstrument.type]!.bufferNode, at: nil, options: .interrupts, completionHandler: nil)

// play the buffer
drumkit[percussiveInstrument.type]!.playerNode.play()
```
You'll notice that there is some code commented out in the class that talks about headphones.  They've introduced HRTF in AVAudioEngine so, as the drums were all mono samples, I was able to position them in space and take advantage of having a spatial, binaural drum kit when I had headphones on.  Mad props to Apple's engineer's for doing this so cleanly and simply.  I'll talk more about the positioning later.

##### Instrument Emitter
This one was definitely another one of [Stan's](https://github.com/wanderingstan) suggestions.  He was over one day and said it would look good if there was a visualisation that went along with it.  Once I started researching options I discovered the [CAEmitterLayer](https://developer.apple.com/documentation/quartzcore/caemitterlayer) which looked like it would do the trick.  There's a great tutorial on all things CALayer over at [raywenderlich.com](https://www.raywenderlich.com/402-calayer-tutorial-for-ios-getting-started) and then, as usual, I got help from some code and comments on [this StackOverflow thread](https://stackoverflow.com/questions/10929316/caemitterlayer-how-to-emit-for-a-short-time-repeatedly).  I started off running them continually but it gave me migraines so I turned them off and then just gave them bursts every time a drum was hit.  That code that makes the magic happen is actually located in ViewController.swift.  There's a dictionary keyed on the PercussionType and when it is notified of the a hit needing displaying it changes the velocity of the emitter to be 1000 then calls itself again 1/10th of a second later and sets the velocity back to 1 again thus resulting in fewer migraines while testing!

##### DrumTrigger.swift
For a class that does so much it really isn't a lot of code.  It uses [CoreMotion](https://developer.apple.com/documentation/coremotion) to obtain the userAcceleration on the z axis.  I got my head start on CoreMotion from the wonderful [NSHipter post](https://nshipster.com/cmdevicemotion/).

Now, let me begin by saying I am definitely not a DSP expert.  I usually come up with my algorithms as needed and definitely not because I've studied a ton of DSP.  This case was no different and I created this algorithm by capturing sample data in a log and then plotting it using Numbers (which, honestly, sucked - but my Excel license had expired!).  This was probably where I spent most of my time. I collected x, y and z data, plotted them, took note of my hits then started defining the algorithm that would fit and also trigger the same hits.  I was able to work out that taking the delta between readings on the z axis, squaring them (to make sure we were only dealing with positive numbers) would give me a great starting point.  I then looked for a value to trigger and hit and found that 0.4 worked pretty well.  Looking for this would be a 'hit detected', resulting in sending a notification to the delegate and pausing for 10 sensor readings (while we waited for the device to stop being impacted by the hit) before starting the process again.  It worked pretty well!  I tried to improve it and sought some help from my friend/former employer [Ross Bencina](http://www.rossbencina.com) (who definitely knows a thing to three about DSP and real time audio!) and he confirmed that what I had implemented was a basic high pass filter and it would do the job, he made some suggestions that were great but probably too much for my fragile maths brain to handle (like different high pass filters, a paper by Miller Pucket on breaking things up into frequency bands, dynamic thresholding, stuff that scared me basically).  If (and this is a big **if**) I was wanting to try and improve this I would probably look at using CoreML and seeing if I could train a machine learning algorithm to detect the hits.  Given you can train a watch to detect curls I figure drumstick hits on an iPad shouldn't be impossible.  Maybe next time.

##### PercussiveInstrument.swift
This is the struct that defines each instrument and percussion type.  It contains the path to the audio sample, the name of the instrument, a UUID (which was used for CoreBluetooth) an an AVAudio3DPoint which was used for the HRTF and positioning in space.  I also ended up using these as the positions on screen for the emitters.  To be honest I wasn't super happy with how this was set up but....it worked so I didn't go back and fix anything.  It just looks uglier than I would like it to and things are hard coded in places.  I think if I spent more time thinking about it I could have made it cleaner.  Also, as someone new to Swift it was weird for me to write a struct like this, so it just kind of *felt wrong*.

##### DrumPeripheral.swift and DrumCentral.swift
I'm not really going to talk about these as I didn't end up using them past proof of concept stage.  I lifted them pretty much straight out of the Apple sample code and adapted them to send a trigger notification rather than a blob of text.  Once I saw they were working I got them built on the tvOS app and then found out that tvOS limits the number of peripherals you can connect to (two on older devices, four on newer devices).  I love BTLE and would have much rather worked with it the whole way than build it in Multipeer Connectivity but, meh, what can you do when Apple hardware blocks you?  Move on!

#### The tvOS app
The tvOS app is basically a straight port of the iOS app except it automatically connects advertises as a multipeer receiver and it changes the background colour of the view if a kick drum hit is detected.

Honestly the hardest part in creating the tvOS app was getting all the bundle icons together.  So. Many. Icons. I conveniently had the icon of the dog with the drumsticks hanging around from an app I worked on way back in the early days with an old bandmate.  Thanks Chris!!  

### Conclusion
Wow, that was a lot.  I really wanted to understand what it was like writing something in Swift and I probably jumped in before I was ready to (there is definitely some ugly code there and I know I'm not using some modern techniques).  But I'm hopeless at reading books on how to code unless I actually need to code and this was definitely worth it!  I really enjoyed working in swift, it took me some time to get my head around to it but by the end I was loving it.  It has been a while now and I look back on the code and forget most of it and wonder what I was doing in half the places, but that's why we write documentation and that's what this is here to help with.  If you want to have a go you should be able to get it running yourself assuming they don't make too many drastic changes to swift (?!).  

I left out the drum samples I was using from this code due to licensing, but if you want them you can get them from [drum-drops for £5]https://www.drum-drops.com/collections/drum-samples/products/60s-rogers-pop-kit.  They sound great!  If I manage to record my own samples (which I should!) I'll eventually put some up so that you don't need to fork over your wallet but drum samples aren't impossible to come by for free either!

Any questions let them in here or shoot me an email or visit some of the other work I've done by heading to [goawaygeek.com](http://goawaygeek.com).
