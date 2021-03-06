//
//  ViewController.swift
//  ARKitTest
//
//  Created by Chris Seonghwan Yoon & Jeremy Ryan on 7/10/17.
//

import UIKit
import ARKit
import SceneKit
import SceneKit.ModelIO
import AVFoundation
import AudioToolbox
import MediaPlayer

// MARK! Fading animation extension for UIView
extension UIView {
    func fadeTransition(_ duration:CFTimeInterval) {
        let animation = CATransition()
        animation.timingFunction = CAMediaTimingFunction(name:
            kCAMediaTimingFunctionEaseInEaseOut)
        animation.type = kCATransitionPush
        animation.subtype = kCATransitionFromTop
        animation.duration = duration
        layer.add(animation, forKey: kCATransitionFade)
    }
}

class ViewController: UIViewController, ARSCNViewDelegate {
    
    // MARK! UI Setup
    @IBOutlet weak var sceneView: ARSCNView!
    
    override var prefersStatusBarHidden: Bool {
        // hide status bar
        return true
    }
    
    var buttonFrameWidth: CGFloat {
        // button frame extends the entire width of screen
        return UIScreen.main.bounds.size.width
    }
    
    var buttonFrameHeight: CGFloat {
        // height of button frame
        return UIScreen.main.bounds.size.height * (1/5)
    }
    
    var displayWidth: CGFloat {
        return UIScreen.main.bounds.size.width
    }
    
    var displayHeight: CGFloat {
        return UIScreen.main.bounds.size.height
    }
    
    var textLabelBuffer: CGFloat {
        // top margin of direction text label
        return buttonFrameHeight * (1/12)
    }
    
    var yOriginOfButtonFrame: CGFloat {
        // y-origin of button frame
        return UIScreen.main.bounds.size.height - buttonFrameHeight
    }
    
    /*
     * UIViewss for all UI button containers
     */
    var getDirectionButton: UIButton!
    var recordPathView: UIView!
    var stopRecordingView: UIView!
    var startNavigationView: UIView!
    var pauseTrackingView: UIView!
    var resumeTrackingView: UIView!
    var resumeTrackingConfirmView: UIView!
    var stopNavigationView: UIView!
    var directionText: UILabel!
    var routeRatingView: UIView!
    var routeRatingLabel: UILabel?
    
    enum ButtonViewType {
        // State of button views
        case recordPath
        case stopRecording
        case startNavigation
        case pauseTracking
        case resumeTracking
        case stopNavigation
    }
    
    var currentButton = ButtonViewType.recordPath
    
    override func viewDidLoad() {
        super.viewDidLoad()
        createSettingsBundle()
        listenVolumeButton()
        createARSession()
        drawUI()
        addGestures()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let userDefaults: UserDefaults = UserDefaults.standard
        let firstTimeLoggingIn: Bool? = userDefaults.object(forKey: "firstTimeLogin") as? Bool
        
        if (firstTimeLoggingIn == nil) {
            userDefaults.set(true, forKey: "firstTimeLogin")
            showLogAlert()
        }
    }
    
    func showLogAlert() {
        // Show logging disclaimer when user opens app for the first time
        let logAlertVC = UIAlertController(title: "Sharing your experience with Clew",
                                           message: "Help us improve the app by logging your Clew experience. These logs will not include any images or personal information. You can turn this off in Settings.",
                                           preferredStyle: .alert)
        logAlertVC.addAction(UIAlertAction(title: "Ok", style: .default, handler: { action -> Void in
            self.showSafetyAlert()
        }
        ))
        self.present(logAlertVC, animated: true, completion: nil)
    }
    
    func showSafetyAlert() {
        // Show safety disclaimer when user opens app for the first time
        let safetyAlertVC = UIAlertController(title: "For your safety",
                                              message: "While using the app, please be aware of your surroundings. You agree that your use of the App is at your own risk, and it is solely your responsibility to maintain your personal safety. Visit www.clewapp.org for more information on how to use the app.",
                                              preferredStyle: .alert)
        safetyAlertVC.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        self.present(safetyAlertVC, animated: true, completion: nil)
    }
    
    /*
     * Configure Settings Bundle
     */
    func createSettingsBundle() {
        registerSettingsBundle()
        updateDisplayFromDefaults()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(defaultsChanged),
                                               name: UserDefaults.didChangeNotification,
                                               object: nil)
    }
    
    func registerSettingsBundle(){
        let appDefaults = ["voiceFeedback": true, "hapticFeedback": true, "sendLogs": true]
        UserDefaults.standard.register(defaults: appDefaults)
    }
    
    func updateDisplayFromDefaults(){
        let defaults = UserDefaults.standard
        
        defaultUnit = defaults.integer(forKey: "units")
        defaultColor = defaults.integer(forKey: "crumbColor")
        soundFeedback = defaults.bool(forKey: "soundFeedback")
        voiceFeedback = defaults.bool(forKey: "voiceFeedback")
        hapticFeedback = defaults.bool(forKey: "hapticFeedback")
        sendLogs = defaults.bool(forKey: "sendLogs")
    }
    
    @objc func defaultsChanged(){
        updateDisplayFromDefaults()
    }
    
    /*
     * Create New ARSession
     */
    func createARSession() {
        configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
        sceneView.delegate = self
        sceneView.backgroundColor = UIColor(patternImage: UIImage(named: "SplashScreen")!)
    }
    
    /*
     * Setup volume listener
     */
    let audioSession = AVAudioSession.sharedInstance()
    func listenVolumeButton() {
        let volumeView: MPVolumeView = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        view.addSubview(volumeView)
        audioSession.addObserver(self, forKeyPath: "outputVolume", options: NSKeyValueObservingOptions.new, context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "outputVolume" {
            if (!paused) {
                print("paused")
                pauseTracking()
                paused = true
            } else {
                print("resume")
                resumeTracking()
                paused = false
            }
        }
    }
    
    var player: AVAudioPlayer?
    @objc func playSound() {
        guard let url = Bundle.main.url(forResource: "Confirm", withExtension: "mp3") else { return }
        
        feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
        feedbackGenerator?.impactOccurred()
        feedbackGenerator = nil
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            player = try AVAudioPlayer(contentsOf: url)
            guard let player = player else { return }
            
            player.play()
            try AVAudioSession.sharedInstance().setActive(false)
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    /*
     * Adds TapGesture to the sceneView
     */
    func addGestures() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(announceDirectionHelp))
        tapGestureRecognizer.numberOfTapsRequired = 2
        self.view.addGestureRecognizer(tapGestureRecognizer)
    }
    
    func drawUI() {
        // button that gives direction to the nearist keypoint
        getDirectionButton = UIButton(frame: CGRect(x: 0, y: 0, width: buttonFrameWidth, height: yOriginOfButtonFrame))
        getDirectionButton.isAccessibilityElement = true
        getDirectionButton.accessibilityLabel = "Get Directions"
        getDirectionButton.isHidden = true
        getDirectionButton.addTarget(self, action: #selector(aannounceDirectionHelpPressed), for: .touchUpInside)
        
        // textlabel that displys directions
        directionText = UILabel(frame: CGRect(x: 0, y: (yOriginOfButtonFrame + textLabelBuffer), width: buttonFrameWidth, height: buttonFrameHeight*(1/6)))
        directionText.textColor = UIColor.white
        directionText.textAlignment = .center
        directionText.isAccessibilityElement = true
        
        
        // Record Path button container
        recordPathView = UIView(frame: CGRect(x: 0, y: yOriginOfButtonFrame, width: buttonFrameWidth, height: buttonFrameHeight))
        recordPathView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        recordPathView.isHidden = false
        addButtons(buttonView: recordPathView, buttonViewType: .recordPath)
        
        
        // Stop Recording button container
        stopRecordingView = UIView(frame: CGRect(x: 0, y: yOriginOfButtonFrame, width: buttonFrameWidth, height: buttonFrameHeight))
        stopRecordingView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        stopRecordingView.isHidden = true
        addButtons(buttonView: stopRecordingView, buttonViewType: .stopRecording)
        
        
        // Start Navigation button container
        startNavigationView = UIView(frame: CGRect(x: 0, y: yOriginOfButtonFrame, width: buttonFrameWidth, height: buttonFrameHeight))
        startNavigationView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        startNavigationView.isHidden = true
        addButtons(buttonView: startNavigationView, buttonViewType: .startNavigation)
        
        
        pauseTrackingView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height))
        pauseTrackingView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        pauseTrackingView.isHidden = true
        drawPauseTrackingView()
        
        
        resumeTrackingView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height))
        resumeTrackingView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        resumeTrackingView.isHidden = true
        drawResumeTrackingView()
        
       resumeTrackingConfirmView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height))
        resumeTrackingConfirmView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        resumeTrackingConfirmView.isHidden = true
        drawResumeTrackingConfrimView()
        
        // Stop Navigation button container
        stopNavigationView = UIView(frame: CGRect(x: 0, y: yOriginOfButtonFrame, width: buttonFrameWidth, height: buttonFrameHeight))
        stopNavigationView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        stopNavigationView.isHidden = true
        addButtons(buttonView: stopNavigationView, buttonViewType: .stopNavigation)
        
        
        routeRatingView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height))
        routeRatingView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        drawRouteRatingView()
        
        self.view.addSubview(recordPathView)
        self.view.addSubview(stopRecordingView)
        self.view.addSubview(startNavigationView)
        self.view.addSubview(pauseTrackingView)
        self.view.addSubview(resumeTrackingView)
        self.view.addSubview(resumeTrackingConfirmView)
        self.view.addSubview(stopNavigationView)
        self.view.addSubview(directionText)
        self.view.addSubview(getDirectionButton)
        self.view.addSubview(routeRatingView)
        showRecordPathButton(announceArrival: false)
    }
    
    func drawRouteRatingView() {
        self.routeRatingLabel = UILabel(frame: CGRect(x: 0, y: displayHeight/2.5, width: displayWidth, height: displayHeight/6))
        routeRatingLabel?.text = "Rate your service."
        routeRatingLabel?.textColor = UIColor.white
        routeRatingLabel?.textAlignment = .center
        
        let buttonWidth = routeRatingView.bounds.size.width / 4.5
        
        let thumbsUpButton = UIButton(type: .custom)
        thumbsUpButton.frame = CGRect(x: 0, y: 0, width: buttonWidth, height: buttonWidth)
        thumbsUpButton.layer.cornerRadius = 0.5 * thumbsUpButton.bounds.size.width
        thumbsUpButton.clipsToBounds = true
        let thumbsUpButtonImage = UIImage(named: "thumbs_up")
        thumbsUpButton.setImage(thumbsUpButtonImage, for: .normal)
        thumbsUpButton.accessibilityLabel = "Good"
        thumbsUpButton.center.x = routeRatingView.center.x + displayWidth/5
        thumbsUpButton.center.y = routeRatingView.bounds.size.height * (2/3)
        thumbsUpButton.addTarget(self, action: #selector(sendLogData), for: .touchUpInside)
        
        let thumbsDownButton = UIButton(type: .custom)
        thumbsDownButton.frame = CGRect(x: 0, y: 0, width: buttonWidth , height: buttonWidth)
        thumbsDownButton.layer.cornerRadius = 0.5 * thumbsUpButton.bounds.size.width
        thumbsDownButton.clipsToBounds = true
        let thumbsDownButtonImage = UIImage(named: "thumbs_down")
        thumbsDownButton.setImage(thumbsDownButtonImage, for: .normal)
        thumbsDownButton.accessibilityLabel = "Bad"
        thumbsDownButton.center.x = routeRatingView.center.x - displayWidth/5
        thumbsDownButton.center.y = routeRatingView.bounds.size.height * (2/3)
        thumbsDownButton.addTarget(self, action: #selector(sendDebugLogData), for: .touchUpInside)
        
        routeRatingView.addSubview(thumbsDownButton)
        routeRatingView.addSubview(thumbsUpButton)
        routeRatingView.addSubview(routeRatingLabel!)
    }
    
    func drawPauseTrackingView() {
        let label = UILabel(frame: CGRect(x: 15, y: displayHeight/3, width: displayWidth-30, height: displayHeight/4))
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        
        label.text = "Place the device against a flat vertical surface and press the volume button to pause. Do not move your phone until you feel a haptic confirmation. You will need to return to this surface to resume tracking. You can use other apps while in pause, but please keep the app running in the background."
        
        pauseTrackingView.addSubview(label)
    }
    
    func drawResumeTrackingView() {
        let label = UILabel(frame: CGRect(x: 15, y: displayHeight/2.5, width: displayWidth-30, height: displayHeight/6))
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        
        label.text = "Return to the last paused location and press Resume for further instructions."
        
        let buttonWidth = resumeTrackingView.bounds.size.width / 4.5
        
        let resumeButton = UIButton(type: .custom)
        resumeButton.frame = CGRect(x: 0, y: 0, width: buttonWidth, height: buttonWidth)
        resumeButton.layer.cornerRadius = 0.5 * resumeButton.bounds.size.width
        resumeButton.clipsToBounds = true
        resumeButton.setTitle("Resume", for: .normal)
        resumeButton.layer.borderWidth = 2
        resumeButton.layer.borderColor = UIColor.white.cgColor
        resumeButton.center.x = pauseTrackingView.center.x
        resumeButton.center.y = pauseTrackingView.bounds.size.height * (4/5)
        resumeButton.addTarget(self, action: #selector(showResumeTrackingConfirmButton), for: .touchUpInside)
        
        resumeTrackingView.addSubview(resumeButton)
        resumeTrackingView.addSubview(label)
    }
    
    func drawResumeTrackingConfrimView() {
        let label = UILabel(frame: CGRect(x: 15, y: displayHeight/2.5, width: displayWidth-30, height: displayHeight/6))
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        
        label.text = "Place the device in the same surface facing the same orientation and press the volume button to resume. Do not move the device until you feel the haptic confirmation."
        resumeTrackingConfirmView.addSubview(label)
    }
    
    /*
     * Adds buttons to given UIView container
     */
    func addButtons(buttonView: UIView, buttonViewType: ButtonViewType) {
        let buttonWidth = buttonView.bounds.size.width / 4.5
        
        let button = UIButton(type: .custom)
        button.frame = CGRect(x: 0, y: 0, width: buttonWidth , height: buttonWidth )
        button.layer.cornerRadius = 0.5 * button.bounds.size.width
        button.clipsToBounds = true
        
        button.center.x = buttonView.center.x
        button.center.y = buttonView.bounds.size.height * (6/10)
        
        // Adds custom button labels
        switch buttonViewType {
        case .recordPath:
            let buttonImage = UIImage(named: "StartRecording")
            button.setImage(buttonImage, for: .normal)
            button.accessibilityLabel = "Record path"
            button.addTarget(self, action: #selector(recordPath), for: .touchUpInside)
        case.stopRecording:
            let buttonImage = UIImage(named: "StopRecording")
            button.setImage(buttonImage, for: .normal)
            button.accessibilityLabel = "Stop recording"
            button.addTarget(self, action: #selector(stopRecording), for: .touchUpInside)
        case .startNavigation:
            let buttonImage = UIImage(named: "StartNavigation")
            button.setImage(buttonImage, for: .normal)
            button.accessibilityLabel = "Start Navigation"
            button.addTarget(self, action: #selector(startNavigation), for: .touchUpInside)
            
            let pauseButton = UIButton(type: .custom)
            pauseButton.frame = CGRect(x: 0, y: 0, width: buttonWidth , height: buttonWidth )
            pauseButton.layer.cornerRadius = 0.5 * button.bounds.size.width
            pauseButton.clipsToBounds = true
            pauseButton.center.x = buttonView.center.x + displayWidth/3
            pauseButton.center.y = buttonView.bounds.size.height * (6/10)
            pauseButton.addTarget(self, action: #selector(showPauseTrackingButton), for: .touchUpInside)
            pauseButton.setTitle("Pause", for: .normal)
            pauseButton.layer.borderWidth = 2
            pauseButton.layer.borderColor = UIColor.white.cgColor
            
            buttonView.addSubview(pauseButton)
        case .pauseTracking:
            button.addTarget(self, action: #selector(pauseTracking), for: .touchUpInside)
            button.setTitle("Pause", for: .normal)
            button.layer.borderWidth = 2
            button.layer.borderColor = UIColor.white.cgColor
        case .resumeTracking:
            button.addTarget(self, action: #selector(resumeTracking), for: .touchUpInside)
            button.setTitle("Resume", for: .normal)
            button.layer.borderWidth = 2
            button.layer.borderColor = UIColor.white.cgColor
        case.stopNavigation:
            let buttonImage = UIImage(named: "StopNavigation")
            button.setImage(buttonImage, for: .normal)
            button.accessibilityLabel = "Stop Navigation"
            button.addTarget(self, action: #selector(stopNavigation), for: .touchUpInside)
        }
        
        buttonView.addSubview(button)
    }
    
    /*
     * display RECORD PATH button/hide all other views
     */
    @objc func showRecordPathButton(announceArrival: Bool) {
        recordPathView.isHidden = false
        stopNavigationView.isHidden = true
        getDirectionButton.isHidden = true

        directionText.isHidden = false
        routeRatingView.isHidden = true
        navigationMode = false
        currentButton = .recordPath
        var helpText: String
        if announceArrival {
            helpText = "You've arrived. Press to record path"
        } else {
            helpText = "Press to record path"
        }
        updateDirectionText(helpText, distance: 0, size: 16, displayDistance: false)
        directionText.isAccessibilityElement = true
        
        delayTransition()
    }
    
    func delayTransition() {
        // this notification currently cuts off the announcement of the button that was just pressed
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil)
    }
    
    /*
     * display STOP RECORDIN button/hide all other views
     */
    @objc func showStopRecordingButton() {
        recordPathView.isHidden = true
        recordPathView.isAccessibilityElement = false
        stopRecordingView.isHidden = false
        currentButton = .stopRecording
        directionText.isAccessibilityElement = true
        updateDirectionText("Hold vertically with the rear camera facing forward.", distance: 0, size: 13, displayDistance: false)
        delayTransition()
    }
    
    /*
     * display START NAVIGATION button/hide all other views
     */
    @objc func showStartNavigationButton() {
        resumeTrackingConfirmView.isHidden = true
        stopRecordingView.isHidden = true
        startNavigationView.isHidden = false
        directionText.isHidden = false
        currentButton = .startNavigation
        directionText.isAccessibilityElement = true
        updateDirectionText("Press to start navigation or pause tracking", distance: 0, size: 14, displayDistance: false)
        do {
            try audioSession.setActive(false)
        } catch {
            print("some error")
        }
        delayTransition()
    }
    
    /*
     * display PAUSE TRACKING button/hide all other views
     */
    @objc func showPauseTrackingButton() throws {
        startNavigationView.isHidden = true
        directionText.isHidden = true
        pauseTrackingView.isHidden = false
        currentButton = .resumeTracking
        do {
            try audioSession.setActive(true)
        } catch {
            print("some error")
        }
        delayTransition()
    }
    
    /*
     * display RESUME TRACKING button/hide all other views
     */
    @objc func showResumeTrackingButton() {
        pauseTrackingView.isHidden = true
        resumeTrackingView.isHidden = false
        currentButton = .resumeTracking
        do {
            try audioSession.setActive(false)
            print("killed active")
        } catch {
            print("some error")
        }
        delayTransition()
    }
    
    @objc func showResumeTrackingConfirmButton() {
        resumeTrackingView.isHidden = true
        resumeTrackingConfirmView.isHidden = false
        do {
            try audioSession.setActive(true)
        } catch {
            print("some error")
        }
        delayTransition()
    }
    
    /*
     * display STOP NAVIGATION button/hide all other views
     */
    @objc func showStopNavigationButton() {
        startNavigationView.isHidden = true
        stopNavigationView.isHidden = false
        getDirectionButton.isHidden = false
        // this does not auto update, so don't use it as an accessibility element
        directionText.isAccessibilityElement = false
        currentButton = .stopNavigation
        delayTransition()
    }
    
    /*
     * display ROUTE RATING button/hide all other views
     */
    @objc func showRouteRating(announceArrival: Bool) {
        stopNavigationView.isHidden = true
        getDirectionButton.isHidden = true
        directionText.isHidden = true
        routeRatingView.isHidden = false
        if announceArrival {
            routeRatingLabel?.text = "You've arrived. Please rate your service."
        } else {
            routeRatingLabel?.text = "Please rate your service."
        }
        currentButton = .stopNavigation
        
        hapticTimer.invalidate()
        
        feedbackGenerator = nil
        waypointFeedbackGenerator = nil
        delayTransition()
    }
    
    /*
     * update directionText UILabel given text string and font size
     * distance Bool used to determine whether to add string "meters" to direction text
     */
    func updateDirectionText(_ discription: String, distance: Float, size: CGFloat, displayDistance: Bool) {
        directionText.fadeTransition(0.4)
        directionText.font = directionText.font.withSize(size)
        var altText = ""
        if(displayDistance) {
            directionText.text = discription + " for \(distance)" + unit[defaultUnit]!
            if(defaultUnit == 0) {
                altText = discription + " for \(Int(distance))" + unitText[defaultUnit]!
            } else {
                if(distance >= 10) {
                    let integer = Int(distance)
                    let decimal = Int((distance - Float(integer)) * 10)
                    altText = discription + "\(integer) point \(decimal)" + unitText[defaultUnit]!
                } else {
                    altText = discription + "\(distance)" + unitText[defaultUnit]!
                }
            }
        } else {
            directionText.text = discription
            altText = discription
        }
        if(navigationMode) {
            speechData.append(altText)
            speechDataTime.append(roundToThousandths(-dataTimer.timeIntervalSinceNow))
        }
        
        // TODO: next line was just if (voiceFeedback)
        if (navigationMode && voiceFeedback) { UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, altText) }
    }
    
    // MARK! BreadCrumbs
    
    // AR Session Configuration
    var configuration: ARWorldTrackingConfiguration!
    
    // Clew internal datastructures
    var crumbs: [LocationInfo]!                 // list of crumbs dropped when recording path
    var keypoints: [KeypointInfo]!              // list of keypoints calculated after path completion
    var keypointNode: SCNNode!                  // SCNNode of the next keypoint
    var prevKeypointPosition: LocationInfo!     // previous keypoint location - originally set to current location
    var turnWarning: Bool!                      // bool to make sure turnWarning happens only once
    var paused: Bool = false
    
    // internal debug logging datastructure
    var dataTimer: Date!                        // timer to sync data
    var pathData: [[Float]] = []                // path data taken during RECORDPATH - [[1x16 transform matrix]]
    var pathDataTime: [Double] = []               // time stamps for pathData
    var navigationData: [[Float]] = []          // path data taken during NAVIGATION - [[1x16 transform matrix]]
    var navigationDataTime: [Double] = []         // time stamps for navigationData
    var speechData: [String]!                   // description data during NAVIGATION
    var speechDataTime: [Double]!               // time stamp for speechData
    var keypointData: [Array<Any>]!             // list of keypoints - [[(LocationInfo)x, y, z, yaw]]
    var trackingErrorData: [String]!            // list of tracking errors ["InsufficientFeatures", "EcessiveMotion"]
    var trackingErrorTime: [Double]!            // time stamp of tracking error
    var trackingErrorPhase: [Bool]!             // tracking phase - true: recording, false: navigation
    
    // Timers for background functions
    var droppingCrumbs: Timer!
    var followingCrumbs: Timer!
    var announcementTimer: Timer!
    var hapticTimer: Timer!
    
    // navigation class and state
    var nav = Navigation()                  // Navigation calculation class
    var navigationMode: Bool = false        // navigation flag
    var recordingMode: Bool = false         // recording flag
    
    // haptic generators
    var feedbackGenerator : UIImpactFeedbackGenerator? = nil
    var waypointFeedbackGenerator: UINotificationFeedbackGenerator? = nil
    var feedbackTimer: Date!
    let FEEDBACKDELAY = 0.4
    
    // settings bundle configuration
    let unit = [0: "ft", 1: "m"]
    let unitText = [0: " feet", 1: " meters"]
    var defaultUnit: Int!
    var defaultColor: Int!
    var soundFeedback: Bool!
    var voiceFeedback: Bool!
    var hapticFeedback: Bool!
    var sendLogs: Bool!
    
    // DirectionText based on hapic/voice settings
    var Directions: Dictionary<Int, String> {
        if (hapticFeedback) {
            return HapticDirections
        } else {
            return CLockDirections
        }
    }
    
    @objc func recordPath() {
        // records a new path
        crumbs = []
        pathData = []
        pathDataTime = []
        dataTimer = Date()
        
        trackingErrorData = []
        trackingErrorTime = []
        trackingErrorPhase = []
        recordingMode = true
        
        showStopRecordingButton()
        droppingCrumbs = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(dropCrum), userInfo: nil, repeats: true)
    }
    
    @objc func stopRecording(_ sender: UIButton) {
        // stop recording current path
        recordingMode = false
        droppingCrumbs.invalidate()
        showStartNavigationButton()
    }
    
    @objc func startNavigation(_ sender: UIButton) {
        // navigate the recorded path
        navigationData = []
        navigationDataTime = []
        speechData = []
        speechDataTime = []
        dataTimer = Date()
        
        // generate path from PathFinder class
        // enabled hapticFeedback generates more keypoints
        let path = PathFinder(crums: crumbs.reversed(), hapticFeedback: hapticFeedback, voiceFeedBack: voiceFeedback)
        keypoints = path.keypoints
        
        // save keypoints data for debug log
        keypointData = []
        for keypoint in keypoints {
            let data = [keypoint.location.x, keypoint.location.y, keypoint.location.z, keypoint.location.yaw]
            keypointData.append(data)
        }
        
        // reder 3D keypoints
        renderKeypoint(keypoints[0].location)
        
        // set navigation state
        navigationMode = true
        turnWarning = false
        prevKeypointPosition = getRealCoordinates(sceneView: sceneView, record: true).location
        
        feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
        waypointFeedbackGenerator = UINotificationFeedbackGenerator()
        
        showStopNavigationButton()
        followingCrumbs = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: (#selector(followCrum)), userInfo: nil, repeats: true)
        
        feedbackTimer = Date()
        hapticTimer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: (#selector(getHapticFeedback)), userInfo: nil, repeats: true)
    }
    
    @objc func stopNavigation(_ sender: UIButton) {
        // stop navigation
        followingCrumbs.invalidate()
        hapticTimer.invalidate()
        
        feedbackGenerator = nil
        waypointFeedbackGenerator = nil
        
        // erase neariest keypoint
        keypointNode.removeFromParentNode()
        
        if(sendLogs) {
            showRouteRating(announceArrival: false)
        } else {
            showRecordPathButton(announceArrival: false)
        }
    }
    
    @objc func pauseTracking() {
        // pause AR pose tracking
        sceneView.session.pause()
        showResumeTrackingButton()
        announcementTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: (#selector(playSound)), userInfo: nil, repeats: false)
    }
    
    @objc func resumeTracking() {
        // resume pose tracking with existing ARSessionConfiguration
        sceneView.session.run(configuration)
        showStartNavigationButton()
        announcementTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: (#selector(playSound)), userInfo: nil, repeats: false)
    }
    
    @objc func sendLogData() {
        // send success log data to AWS
        compileLogData(false)
        showRecordPathButton(announceArrival: false)
        delayTransition()
    }
    
    @objc func sendDebugLogData() {
        // send debug log data to AWS
        compileLogData(true)
        showRecordPathButton(announceArrival: false)
    }
    
    func compileLogData(_ debug: Bool) {
        // compile log data
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        let pathDate = dateFormatter.string(from: date)
        let pathID = UIDevice.current.identifierForVendor!.uuidString + dateFormatter.string(from: date)
        let userId = UIDevice.current.identifierForVendor!.uuidString
        
        sendMetaData(pathDate, pathID+"-0", userId, debug)
        sendPathData(pathID, userId)
    }
    
    func sendMetaData(_ pathDate: String, _ pathID: String, _ userId: String, _ debug: Bool) {
        let pathType: String!
        if(debug) {
            pathType = "bug"
        } else {
            pathType = "success"
        }
        
        let body: [String : Any] = ["userId": userId,
                                    "PathID": pathID,
                                    "PathDate": pathDate,
                                    "PathType": pathType,
                                    "keypointData": keypointData,
                                    "trackingErrorPhase": trackingErrorPhase,
                                    "trackingErrorTime": trackingErrorTime,
                                    "trackingErrorData": trackingErrorData]
        
        let bodyText: String!
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
            // here "jsonData" is the dictionary encoded in JSON data
            bodyText = String(data: jsonData, encoding: String.Encoding.utf8)
            
            // create http post request to AWS
            var request = URLRequest(url: URL(string: "https://27bcct7nyg.execute-api.us-east-1.amazonaws.com/Test/pathid")!)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyText.data(using: .utf8)
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {                                                 // check for fundamental networking error
                    print("error=\(String(describing: error))")
                    return
                }
                
                if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {           // check for http errors
                    print("statusCode should be 200, but is \(httpStatus.statusCode)")
                    print("response = \(String(describing: response))")
                }
                
                let responseString = String(data: data, encoding: .utf8)
                print("responseString = \(String(describing: responseString))")
            }
            task.resume()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func sendPathData(_ pathID: String, _ userId: String) {
        var id = 1
        var pd = [[Float]]()
        var pdt = [Double]()
        var nd = [[Float]]()
        var ndt = [Double]()
        var sd = [String]()
        var sdt = [Double]()
        
        while(!pathData.isEmpty || !navigationData.isEmpty || !speechData.isEmpty) {
            print(id)
            if(pathData.count >= 75) {
                pd = Array(pathData[0..<75])
                pdt = Array(pathDataTime[0..<75])
                pathData = Array(pathData[75..<pathData.count])
                pathDataTime = Array(pathDataTime[75..<pathDataTime.count])
            } else {
                pd = pathData
                pdt = pathDataTime
                if(pathData.count > 0) {
                    pathData = []
                    pathDataTime = []
                }
            }
            if(navigationData.count >= 75) {
                nd = Array(navigationData[0..<75])
                ndt = Array(navigationDataTime[0..<75])
                navigationData = Array(navigationData[75..<navigationData.count])
                navigationDataTime = Array(navigationDataTime[75..<navigationDataTime.count])
            } else {
                nd = navigationData
                ndt = navigationDataTime
                if(navigationData.count > 0) {
                    navigationData = []
                    navigationDataTime = []
                }
            }
            if(speechData.count >= 20) {
                sd = Array(speechData[0..<20])
                sdt = Array(speechDataTime[0..<20])
                speechData = Array(speechData[20..<pathData.count])
                speechDataTime = Array(speechDataTime[20..<pathDataTime.count])
            } else {
                sd = speechData
                sdt = speechDataTime
                if(speechData.count > 0) {
                    speechData = []
                    speechDataTime = []
                }
            }
            
            
            let body: [String : Any] = ["userId": userId,
                                        "PathID": pathID + "-\(id)",
                                        "PathDate": "0",
                                        "PathType": "0",
                                        "PathData": pd,
                                        "pathDataTime": pdt,
                                        "navigationData": nd,
                                        "navigationDataTime": ndt,
                                        "speechData": sd,
                                        "speechDataTime": sdt]
            
            let bodyText: String!
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
                // here "jsonData" is the dictionary encoded in JSON data
                bodyText = String(data: jsonData, encoding: String.Encoding.utf8)
                
                // create http post request to AWS
                var request = URLRequest(url: URL(string: "https://27bcct7nyg.execute-api.us-east-1.amazonaws.com/Test/pathid")!)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = bodyText.data(using: .utf8)
                //            print(request.httpBody)
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    guard let data = data, error == nil else {                                                 // check for fundamental networking error
                        print("error=\(String(describing: error))")
                        return
                    }
                    
                    if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {           // check for http errors
                        print("statusCode should be 200, but is \(httpStatus.statusCode)")
                        print("response = \(String(describing: response))")
                    }
                    
                    let responseString = String(data: data, encoding: .utf8)
                    print("responseString = \(String(describing: responseString))")
                }
                task.resume()
            } catch {
                print(error.localizedDescription)
            }
            id += 1
        }
    }
    
    @objc func dropCrum() {
        // drop waypoint markers to record path
        let curLocation = getRealCoordinates(sceneView: sceneView, record: true).location
        crumbs.append(curLocation)
    }
    
    @objc func followCrum() {
        // checks to see if user is on the right path during navigation
        let curLocation = getRealCoordinates(sceneView: sceneView, record: true)
        var directionToNextKeypoint = getDirectionToNextKeypoint(currentLocation: curLocation)
        
        if (shouldAnnounceTurnWarning(directionToNextKeypoint)) {
            announceTurnWarning(curLocation)
        } else if (directionToNextKeypoint.targetState == PositionState.atTarget) {
            if (keypoints.count > 1) {
                // arrived at keypoint
                // send haptic/sonic feedback
                waypointFeedbackGenerator?.notificationOccurred(.success)
                if (soundFeedback) { AudioServicesPlaySystemSound(SystemSoundID(1016)) }
                
                // remove current visited keypont from keypoint list
                prevKeypointPosition = keypoints[0].location
                keypoints.remove(at: 0)
                
                // erase current keypoint and render next keypoint node
                keypointNode.removeFromParentNode()
                renderKeypoint(keypoints[0].location)
                
                // update directions to next keypoint
                directionToNextKeypoint = getDirectionToNextKeypoint(currentLocation: curLocation)
                setDirectionText(currentLocation: curLocation.location, direction: directionToNextKeypoint, displayDistance: false)
                turnWarning = false
            } else {
                // arrived at final keypoint
                // send haptic/sonic feedback
                waypointFeedbackGenerator?.notificationOccurred(.success)
                if (soundFeedback) { AudioServicesPlaySystemSound(SystemSoundID(1016)) }
                
                // erase current keypoint node
                keypointNode.removeFromParentNode()
                
                // update text and stop navigation
                announceArrival()
                followingCrumbs.invalidate()
            }
        }
        
    }
    
    @objc func getHapticFeedback() {
        // send haptic feedback depending on correct device
        let curLocation = getRealCoordinates(sceneView: sceneView, record: false)
        let directionToNextKeypoint = getDirectionToNextKeypoint(currentLocation: curLocation)
        
        if(directionToNextKeypoint.clockDirection == 12) {
            let timeInterval = feedbackTimer.timeIntervalSinceNow
            if(-timeInterval > FEEDBACKDELAY) {
                // wait until desired time interval before sending another feedback
                if (hapticFeedback) { feedbackGenerator?.impactOccurred() }
                if (soundFeedback) { AudioServicesPlaySystemSound(SystemSoundID(1103)) }
                feedbackTimer = Date()
            }
        }
    }
    
    func shouldAnnounceTurnWarning(_ direction: DirectionInfo) -> Bool {
        // check if app should make a turn warning annoucement
        return direction.targetState == PositionState.closeToTarget &&
            !turnWarning &&
            keypoints.count > 1 &&
            sqrtf(powf(Float(keypoints[0].location.x - prevKeypointPosition.x),2) + powf(Float(keypoints[0].location.z - prevKeypointPosition.z),2)) >= 6
    }
    
    func announceTurnWarning(_ currentLocation: CurrentCoordinateInfo) {
        // announce upcoming turn
        var dir = nav.getTurnWarningDirections(currentLocation, curKeypoint: keypoints[0], nextKeypoint: keypoints[1])
        if(defaultUnit == 0) {
            // convert to imperial units
            dir.distance *= 3.28084
        }
        dir.distance = roundToTenths(dir.distance)
        turnWarning = true
        setTurnWarningText(currentLocation: currentLocation.location, direction: dir)
    }
    
    func getDirectionToNextKeypoint(currentLocation: CurrentCoordinateInfo) -> DirectionInfo {
        // returns direction to next keypoint from current location
        var dir = nav.getDirections(currentLocation: currentLocation, nextKeypoint: keypoints[0])
        dir.distance = roundToTenths(dir.distance)
        return dir
    }
    
    @objc func aannounceDirectionHelpPressed() {
        announcementTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: (#selector(announceDirectionHelp)), userInfo: nil, repeats: false)
    }
    
    @objc func announceDirectionHelp() {
        // announce directions at any given point to the next keypoint
        if (navigationMode) {
            let curLocation = getRealCoordinates(sceneView: sceneView, record: false)
            let directionToNextKeypoint = getDirectionToNextKeypoint(currentLocation: curLocation)
            setDirectionText(currentLocation: curLocation.location, direction: directionToNextKeypoint, displayDistance: true)
        }
    }
    
    func setTurnWarningText(currentLocation: LocationInfo, direction: DirectionInfo) {
        // update display text for text label and VoiceOver
        let xzNorm = sqrtf(powf(currentLocation.x - keypoints[0].location.x, 2) + powf(currentLocation.z - keypoints[0].location.z, 2))
        let slope = (keypoints[1].location.y - keypoints[0].location.y) / xzNorm
        var dir = ""
        
        if(slope > 0.3) { // Go upstairs
            if(hapticFeedback) {
                dir += "\(TurnWarnings[direction.hapticDirection]!) and proceed upstairs"
            } else {
                dir += "\(TurnWarnings[direction.clockDirection]!) and proceed upstairs"
            }
            updateDirectionText(dir, distance: 0, size: 12, displayDistance: false)
        } else if (slope < -0.3) { // Go downstairs
            if(hapticFeedback) {
                dir += "\(TurnWarnings[direction.hapticDirection]!) and proceed downstairs"
            } else {
                dir += "\(TurnWarnings[direction.clockDirection]!) and proceed downstairs"
            }
            updateDirectionText(dir, distance: direction.distance,size: 12, displayDistance: false)
        } else { // nromal directions
            if(hapticFeedback) {
                dir += "\(TurnWarnings[direction.hapticDirection]!)"
            } else {
                dir += "\(TurnWarnings[direction.clockDirection]!)"
            }
            updateDirectionText(dir, distance: direction.distance, size: 16, displayDistance:  false)
        }
    }
    
    func setDirectionText(currentLocation: LocationInfo, direction: DirectionInfo, displayDistance: Bool) {
        // Set direction text for text label and VoiceOver
        let xzNorm = sqrtf(powf(currentLocation.x - keypoints[0].location.x, 2) + powf(currentLocation.z - keypoints[0].location.z, 2))
        let slope = (keypoints[0].location.y - prevKeypointPosition.y) / xzNorm
        var dir = ""
        
        if(slope > 0.3) { // Go upstairs
            if(hapticFeedback) {
                dir += "\(Directions[direction.hapticDirection]!) and proceed upstairs"
            } else {
                dir += "\(Directions[direction.clockDirection]!) and proceed upstairs"
            }
            updateDirectionText(dir, distance: 0, size: 12, displayDistance: false)
        } else if (slope < -0.3) { // Go downstairs
            if(hapticFeedback) {
                dir += "\(Directions[direction.hapticDirection]!) and proceed downstairs"
            } else {
                dir += "\(Directions[direction.clockDirection]!) and proceed downstairs"
            }
            updateDirectionText(dir, distance: direction.distance,size: 12, displayDistance: false)
        } else { // nromal directions
            if(hapticFeedback) {
                dir += "\(Directions[direction.hapticDirection]!)"
            } else {
                dir += "\(Directions[direction.clockDirection]!)"
            }
            updateDirectionText(dir, distance: direction.distance, size: 16, displayDistance:  displayDistance)
        }
    }
    
    func announceArrival() {
        // announce destination arrival
        if(sendLogs) {
            showRouteRating(announceArrival: true)
        } else {
            showRecordPathButton(announceArrival: true)
        }
    }
    
    func renderKeypoint(_ location: LocationInfo) {
        // render SCNNode of given keypoint
        let bundle = Bundle.main
        let path = bundle.path(forResource: "Crumb", ofType: "obj")
        let url = NSURL(fileURLWithPath: path!)
        let asset = MDLAsset(url: url as URL)
        let object = asset.object(at: 0)
        keypointNode = SCNNode(mdlObject: object)
        
        // configure node attributes
        keypointNode.scale = SCNVector3(0.0004, 0.0004, 0.0004)
        keypointNode.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        keypointNode.position = SCNVector3(location.x, location.y - 0.2, location.z)
        keypointNode.rotation = SCNVector4(0, 1, 0, (location.yaw - Float.pi/2))
        
        let bound = SCNVector3(
            x: keypointNode.boundingBox.max.x - keypointNode.boundingBox.min.x,
            y: keypointNode.boundingBox.max.y - keypointNode.boundingBox.min.y,
            z: keypointNode.boundingBox.max.z - keypointNode.boundingBox.min.z)
        keypointNode.pivot = SCNMatrix4MakeTranslation(bound.x / 2, bound.y / 2, bound.z / 2)
        
        let spin = CABasicAnimation(keyPath: "rotation")
        spin.fromValue = NSValue(scnVector4: SCNVector4(x: 0, y: 1, z: 0, w: 0))
        spin.toValue = NSValue(scnVector4: SCNVector4(x: 0, y: 1, z: 0, w: Float(CGFloat(2 * Float.pi))))
        spin.duration = 3
        spin.repeatCount = .infinity
        keypointNode.addAnimation(spin, forKey: "spin around")
        
        // animation - SCNNode flashes red
        let flashRed = SCNAction.customAction(duration: 2) { (node, elapsedTime) -> () in
            let percentage = Float(elapsedTime / 2)
            var color = UIColor.clear
            let power: Float = 2.0
            
            
            if (percentage < 0.5) {
                color = UIColor(red: 1,
                                green: CGFloat(powf(2.0*percentage, power)),
                                blue: CGFloat(powf(2.0*percentage, power)),
                                alpha: 1)
            } else {
                color = UIColor(red: 1,
                                green: CGFloat(powf(2-2.0*percentage, power)),
                                blue: CGFloat(powf(2-2.0*percentage, power)),
                                alpha: 1)
            }
            node.geometry!.firstMaterial!.diffuse.contents = color
        }
        
        // animation - SCNNode flashes green
        let flashGreen = SCNAction.customAction(duration: 2) { (node, elapsedTime) -> () in
            let percentage = Float(elapsedTime / 2)
            var color = UIColor.clear
            let power: Float = 2.0
            
            
            if (percentage < 0.5) {
                color = UIColor(red: CGFloat(powf(2.0*percentage, power)),
                                green: 1,
                                blue: CGFloat(powf(2.0*percentage, power)),
                                alpha: 1)
            } else {
                color = UIColor(red: CGFloat(powf(2-2.0*percentage, power)),
                                green: 1,
                                blue: CGFloat(powf(2-2.0*percentage, power)),
                                alpha: 1)
            }
            node.geometry!.firstMaterial!.diffuse.contents = color
        }
        
        // animation - SCNNode flashes blue
        let flashBlue = SCNAction.customAction(duration: 2) { (node, elapsedTime) -> () in
            let percentage = Float(elapsedTime / 2)
            var color = UIColor.clear
            let power: Float = 2.0
            
            
            if (percentage < 0.5) {
                color = UIColor(red: CGFloat(powf(2.0*percentage, power)),
                                green: CGFloat(powf(2.0*percentage, power)),
                                blue: 1,
                                alpha: 1)
            } else {
                color = UIColor(red: CGFloat(powf(2-2.0*percentage, power)),
                                green: CGFloat(powf(2-2.0*percentage, power)),
                                blue: 1,
                                alpha: 1)
            }
            node.geometry!.firstMaterial!.diffuse.contents = color
        }
        let flashColors = [flashRed, flashGreen, flashBlue]
        
        // set flashing color based on settings bundle configuration
        var changeColor: SCNAction!
        if (defaultColor == 3) {
            changeColor = SCNAction.repeatForever(flashColors[Int(arc4random_uniform(3))])
        } else {
            changeColor = SCNAction.repeatForever(flashColors[defaultColor])
        }
        
        // add keypoint node to view
        keypointNode.runAction(changeColor)
        sceneView.scene.rootNode.addChildNode(keypointNode)
    }
    
    func getCameraCoordinates(sceneView: ARSCNView) -> LocationInfo {
        // returns coordinate frame of the camera
        let cameraTransform = sceneView.session.currentFrame?.camera.transform
        let coordinates = MDLTransform(matrix: cameraTransform!)
        
        return LocationInfo(x: coordinates.translation.x,
                            y: coordinates.translation.y,
                            z: coordinates.translation.z,
                            yaw: coordinates.rotation.y)
    }
    
    func getRealCoordinates(sceneView: ARSCNView, record: Bool) -> CurrentCoordinateInfo {
        // returns current location & orientation based on starting origin
        let x = SCNMatrix4((sceneView.session.currentFrame?.camera.transform)!).m41
        let y = SCNMatrix4((sceneView.session.currentFrame?.camera.transform)!).m42
        let z = SCNMatrix4((sceneView.session.currentFrame?.camera.transform)!).m43
        
        let yaw = sceneView.session.currentFrame?.camera.eulerAngles.y
        let scn = SCNMatrix4((sceneView.session.currentFrame?.camera.transform)!)
        let transMatrix = Matrix3([scn.m11, scn.m12, scn.m13,
                                   scn.m21, scn.m22, scn.m23,
                                   scn.m31, scn.m32, scn.m33])
        
        // record location data in debug logs
        if(record) {
            if (navigationMode) {
                navigationData.append([round10k(scn.m11), round10k(scn.m12), round10k(scn.m13), round10k(scn.m14),
                                       round10k(scn.m21), round10k(scn.m22), round10k(scn.m23), round10k(scn.m24),
                                       round10k(scn.m31), round10k(scn.m32), round10k(scn.m33), round10k(scn.m34),
                                       round10k(scn.m41), round10k(scn.m42), round10k(scn.m43), round10k(scn.m44)])
                navigationDataTime.append(roundToThousandths(-dataTimer.timeIntervalSinceNow))
            } else {
                pathData.append([round10k(scn.m11), round10k(scn.m12), round10k(scn.m13), round10k(scn.m14),
                                 round10k(scn.m21), round10k(scn.m22), round10k(scn.m23), round10k(scn.m24),
                                 round10k(scn.m31), round10k(scn.m32), round10k(scn.m33), round10k(scn.m34),
                                 round10k(scn.m41), round10k(scn.m42), round10k(scn.m43), round10k(scn.m44)])
                pathDataTime.append(roundToThousandths(-dataTimer.timeIntervalSinceNow))
            }
        }
        
        return CurrentCoordinateInfo(LocationInfo(x: x, y: y, z: z, yaw: yaw!), transMatrix: transMatrix)
    }
    
    /*
     * Called when there is a change in tracking state
     */
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        if(recordingMode) {
            trackingErrorPhase.append(true)
        } else if (navigationMode) {
            trackingErrorPhase.append(false)
        }
        
        if(recordingMode || navigationMode) {
            trackingErrorTime.append(roundToThousandths(-dataTimer.timeIntervalSinceNow))
            switch camera.trackingState {
            case .limited(let reason):
                switch reason {
                case .excessiveMotion:
                    trackingErrorData.append("ExcessiveMotion")
                    print("ExcessiveMotion")
                case .insufficientFeatures:
                    trackingErrorData.append("InsufficientFeatures")
                    print("InsufficientFeatures")
                case .initializing:
                    return
                case .relocalizing:
                    trackingErrorData.append("Relocalizing")
                    print("Relocalizing")
                }
            case .normal:
                trackingErrorData.append("Normal")
                print("normal")
            case .notAvailable:
                trackingErrorData.append("NotAvailable")
                print("notAvailable")
            }
        }
    }
}
