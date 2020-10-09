import AudioKit
import AVFoundation
import SwiftUI

struct AutoWahData {
    var wah: AUValue = 0.0
    var mix: AUValue = 1.0
    var amplitude: AUValue = 0.1
    var rampDuration: AUValue = 0.02
    var balance: AUValue = 0.5
}

class AutoWahConductor: ObservableObject, ProcessesPlayerInput {

    let engine = AudioEngine()
    let player = AudioPlayer()
    let autowah: AutoWah
    let dryWetMixer: DryWetMixer
    let playerPlot: NodeOutputPlot
    let autowahPlot: NodeOutputPlot
    let mixPlot: NodeOutputPlot
    let buffer: AVAudioPCMBuffer

    init() {
        let url = Bundle.main.resourceURL?.appendingPathComponent("Samples/beat.aiff")
        let file = try! AVAudioFile(forReading: url!)
        buffer = try! AVAudioPCMBuffer(file: file)!

        autowah = AutoWah(player)
        dryWetMixer = DryWetMixer(player, autowah)
        playerPlot = NodeOutputPlot(player)
        autowahPlot = NodeOutputPlot(autowah)
        mixPlot = NodeOutputPlot(dryWetMixer)

        engine.output = dryWetMixer

        playerPlot.plotType = .rolling
        playerPlot.shouldFill = true
        playerPlot.shouldMirror = true
        playerPlot.setRollingHistoryLength(128)
        autowahPlot.plotType = .rolling
        autowahPlot.color = .blue
        autowahPlot.shouldFill = true
        autowahPlot.shouldMirror = true
        autowahPlot.setRollingHistoryLength(128)
        mixPlot.color = .purple
        mixPlot.shouldFill = true
        mixPlot.shouldMirror = true
        mixPlot.plotType = .rolling
        mixPlot.setRollingHistoryLength(128)
    }

    @Published var data = AutoWahData() {
        didSet {
            autowah.$wah.ramp(to: data.wah, duration: data.rampDuration)
            autowah.$mix.ramp(to: data.mix, duration: data.rampDuration)
            autowah.$amplitude.ramp(to: data.amplitude, duration: data.rampDuration)
            dryWetMixer.balance = data.balance
        }
    }

    func start() {
        playerPlot.start()
        autowahPlot.start()
        mixPlot.start()

        do {
            try engine.start()
            // player stuff has to be done after start
            player.scheduleBuffer(buffer, at: nil, options: .loops)
        } catch let err {
            Log(err)
        }
        player.play()
    }

    func stop() {
        engine.stop()
    }
}

struct AutoWahView: View {
    @ObservedObject var conductor = AutoWahConductor()

    var body: some View {
        ScrollView {
            PlayerControls(conductor: conductor)
            ParameterSlider(text: "Wah",
                            parameter: self.$conductor.data.wah,
                            range: 0.0...1.0,
                            units: "Percent")
            ParameterSlider(text: "Mix",
                            parameter: self.$conductor.data.mix,
                            range: 0.0...1.0,
                            units: "Percent")
            ParameterSlider(text: "Amplitude",
                            parameter: self.$conductor.data.amplitude,
                            range: 0.0...1.0,
                            units: "Percent")
            ParameterSlider(text: "Mix",
                            parameter: self.$conductor.data.balance,
                            range: 0...1,
                            units: "%")
            DryWetMixPlotsView(dry: conductor.playerPlot, wet: conductor.autowahPlot, mix: conductor.mixPlot)
        }
        .padding()
        .navigationBarTitle(Text("Auto Wah"))
        .onAppear {
            self.conductor.start()
        }
        .onDisappear {
            self.conductor.stop()
        }
    }
}

struct AutoWah_Previews: PreviewProvider {
    static var previews: some View {
        AutoWahView()
    }
}
