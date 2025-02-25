//
//  popup.swift
//  Net
//
//  Created by Serhiy Mytrovtsiy on 24/05/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Popup: PopupWrapper {
    private var title: String
    
    private var uploadView: NSView? = nil
    private var uploadValue: Int64 = 0
    private var uploadValueField: NSTextField? = nil
    private var uploadUnitField: NSTextField? = nil
    private var uploadStateView: ColorView? = nil
    
    private var downloadView: NSView? = nil
    private var downloadValue: Int64 = 0
    private var downloadValueField: NSTextField? = nil
    private var downloadUnitField: NSTextField? = nil
    private var downloadStateView: ColorView? = nil
    
    private var downloadColorView: NSView? = nil
    private var uploadColorView: NSView? = nil
    
    private var localIPField: ValueField? = nil
    private var interfaceField: ValueField? = nil
    private var macAddressField: ValueField? = nil
    private var totalUploadLabel: LabelField? = nil
    private var totalUploadField: ValueField? = nil
    private var totalDownloadLabel: LabelField? = nil
    private var totalDownloadField: ValueField? = nil
    private var statusField: ValueField? = nil
    private var connectivityField: ValueField? = nil
    private var latencyField: ValueField? = nil
    
    private var publicIPStackView: NSView? = nil
    private var publicIPv4Field: ValueField? = nil
    private var publicIPv6Field: ValueField? = nil
    
    private var ssidField: ValueField? = nil
    private var standardField: ValueField? = nil
    private var channelField: ValueField? = nil
    
    private var processesView: NSView? = nil
    
    private var initialized: Bool = false
    private var processesInitialized: Bool = false
    private var connectionInitialized: Bool = false
    
    private var chart: NetworkChartView? = nil
    private var reverseOrderState: Bool = false
    private var chartScale: Scale = .none
    private var chartFixedScale: Int = 12
    private var chartFixedScaleSize: SizeUnit = .MB
    private var chartPrefSection: PreferencesSection? = nil
    private var connectivityChart: GridChartView? = nil
    private var processes: ProcessesView? = nil
    private var sliderView: NSView? = nil
    private var publicIPState: Bool = true
    
    private var lastReset: Date = Date()
    
    private var base: DataSizeBase {
        DataSizeBase(rawValue: Store.shared.string(key: "\(self.title)_base", defaultValue: "byte")) ?? .byte
    }
    private var numberOfProcesses: Int {
        Store.shared.int(key: "\(self.title)_processes", defaultValue: 8)
    }
    private var processesHeight: CGFloat {
        (22*CGFloat(self.numberOfProcesses)) + (self.numberOfProcesses == 0 ? 0 : Constants.Popup.separatorHeight + 22)
    }
    
    private var downloadColorState: Color = .secondBlue
    private var downloadColor: NSColor {
        var value = NSColor.systemBlue
        if let color = self.downloadColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    private var uploadColorState: Color = .secondRed
    private var uploadColor: NSColor {
        var value = NSColor.systemRed
        if let color = self.uploadColorState.additional as? NSColor {
            value = color
        }
        return value
    }
    
    private var latency: [Double] = []
    
    public init(_ module: ModuleType) {
        self.title = module.rawValue
        
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: Constants.Popup.width,
            height: 0
        ))
        
        self.downloadColorState = Color.fromString(Store.shared.string(key: "\(self.title)_downloadColor", defaultValue: self.downloadColorState.key))
        self.uploadColorState = Color.fromString(Store.shared.string(key: "\(self.title)_uploadColor", defaultValue: self.uploadColorState.key))
        self.reverseOrderState = Store.shared.bool(key: "\(self.title)_reverseOrder", defaultValue: self.reverseOrderState)
        self.chartScale = Scale.fromString(Store.shared.string(key: "\(self.title)_chartScale", defaultValue: self.chartScale.key))
        self.chartFixedScale = Store.shared.int(key: "\(self.title)_chartFixedScale", defaultValue: self.chartFixedScale)
        self.chartFixedScaleSize = SizeUnit.fromString(Store.shared.string(key: "\(self.title)_chartFixedScaleSize", defaultValue: self.chartFixedScaleSize.key))
        self.publicIPState = Store.shared.bool(key: "\(self.title)_publicIP", defaultValue: self.publicIPState)
        
        self.spacing = 0
        self.orientation = .vertical
        
        self.addArrangedSubview(self.initDashboard())
        self.addArrangedSubview(self.initChart())
        self.addArrangedSubview(self.initConnectivityChart())
        self.addArrangedSubview(self.initDetails())
        self.addArrangedSubview(self.initPublicIP())
        self.addArrangedSubview(self.initProcesses())
        
        if !self.publicIPState {
            self.publicIPStackView?.removeFromSuperview()
        }
        
        self.recalculateHeight()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.resetTotalNetworkUsageCallback), name: .resetTotalNetworkUsage, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .resetTotalNetworkUsage, object: nil)
    }
    
    private func recalculateHeight() {
        let h = self.arrangedSubviews.map({ $0.bounds.height }).reduce(0, +)
        if self.frame.size.height != h {
            self.setFrameSize(NSSize(width: self.frame.width, height: h))
            self.sizeCallback?(self.frame.size)
        }
    }
    
    // MARK: - views
    
    private func initDashboard() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 90))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        
        let leftPart: NSView = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width / 2, height: view.frame.height))
        let downloadFields = self.topValueView(leftPart, title: localizedString("Downloading"), color: self.downloadColor)
        self.downloadView = downloadFields.0
        self.downloadValueField = downloadFields.1
        self.downloadUnitField = downloadFields.2
        self.downloadStateView = downloadFields.3
        
        let rightPart: NSView = NSView(frame: NSRect(x: view.frame.width / 2, y: 0, width: view.frame.width / 2, height: view.frame.height))
        let uploadFields = self.topValueView(rightPart, title: localizedString("Uploading"), color: self.uploadColor)
        self.uploadView = uploadFields.0
        self.uploadValueField = uploadFields.1
        self.uploadUnitField = uploadFields.2
        self.uploadStateView = uploadFields.3
        
        view.addSubview(leftPart)
        view.addSubview(rightPart)
        
        return view
    }
    
    private func initChart() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 90 + Constants.Popup.separatorHeight))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        
        let separator = separatorView(localizedString("Usage history"), origin: NSPoint(x: 0, y: 90), width: self.frame.width)
        let container: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
        container.layer?.cornerRadius = 3
        
        let chart = NetworkChartView(
            frame: NSRect(x: 0, y: 1, width: container.frame.width, height: container.frame.height - 2),
            num: 120, reversedOrder: self.reverseOrderState, outColor: self.uploadColor, inColor: self.downloadColor, 
            scale: self.chartScale,
            fixedScale: Double(self.chartFixedScaleSize.toBytes(self.chartFixedScale))
        )
        chart.base = self.base
        container.addSubview(chart)
        self.chart = chart
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initConnectivityChart() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 30 + Constants.Popup.separatorHeight))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        let separator = separatorView(localizedString("Connectivity history"), origin: NSPoint(x: 0, y: 30), width: self.frame.width)
        let container: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
        container.layer?.cornerRadius = 3
        
        let chart = GridChartView(frame: NSRect(x: 0, y: 1, width: container.frame.width, height: container.frame.height - 2), grid: (30, 3))
        container.addSubview(chart)
        self.connectivityChart = chart
        
        view.addSubview(separator)
        view.addSubview(container)
        
        return view
    }
    
    private func initDetails() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 0))
        let container: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 0))
        container.orientation = .vertical
        container.spacing = 0
        
        let row: NSView = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: Constants.Popup.separatorHeight))
        
        let button = NSButtonWithPadding()
        button.frame = CGRect(x: view.frame.width - 18, y: 6, width: 18, height: 18)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imageScaling = NSImageScaling.scaleAxesIndependently
        button.contentTintColor = .lightGray
        button.action = #selector(self.resetTotalNetworkUsage)
        button.target = self
        button.toolTip = localizedString("Reset")
        button.image = Bundle(for: Module.self).image(forResource: "refresh")!
        
        row.addSubview(separatorView(localizedString("Details"), origin: NSPoint(x: 0, y: 0), width: self.frame.width))
        row.addSubview(button)
        
        container.addArrangedSubview(row)
        
        let totalUpload = popupWithColorRow(container, color: self.uploadColor, n: 0, title: "\(localizedString("Total upload")):", value: "0")
        let totalDownload = popupWithColorRow(container, color: self.downloadColor, n: 0, title: "\(localizedString("Total download")):", value: "0")
        
        self.uploadColorView = totalUpload.0
        self.totalUploadLabel = totalUpload.1
        self.totalUploadField = totalUpload.2
        
        self.downloadColorView = totalDownload.0
        self.totalDownloadLabel = totalDownload.1
        self.totalDownloadField = totalDownload.2
        
        self.statusField = popupRow(container, n: 0, title: "\(localizedString("Status")):", value: localizedString("Unknown")).1
        self.connectivityField = popupRow(container, n: 0, title: "\(localizedString("Internet connection")):", value: localizedString("Unknown")).1
        self.latencyField = popupRow(container, n: 0, title: "\(localizedString("Latency")):", value: "0 ms").1
        
        self.interfaceField = popupRow(container, n: 0, title: "\(localizedString("Interface")):", value: localizedString("Unknown")).1
        self.ssidField = popupRow(container, n: 0, title: "\(localizedString("Network")):", value: localizedString("Unknown")).1
        self.standardField = popupRow(container, n: 0, title: "\(localizedString("Standard")):", value: localizedString("Unknown")).1
        self.channelField = popupRow(container, n: 0, title: "\(localizedString("Channel")):", value: localizedString("Unknown")).1
        
        self.macAddressField = popupRow(container, n: 0, title: "\(localizedString("Physical address")):", value: localizedString("Unknown")).1
        self.localIPField = popupRow(container, n: 0, title: "\(localizedString("Local IP")):", value: localizedString("Unknown")).1
        
        self.localIPField?.isSelectable = true
        self.macAddressField?.isSelectable = true
        
        view.addSubview(container)
        
        let h = container.arrangedSubviews.map({ $0.bounds.height }).reduce(0, +)
        view.setFrameSize(NSSize(width: self.frame.width, height: h))
        container.setFrameSize(NSSize(width: self.frame.width, height: view.bounds.height))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        container.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        
        return view
    }
    
    private func initPublicIP() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 0))
        let container: NSStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 0))
        container.orientation = .vertical
        container.spacing = 0
        
        let row: NSView = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: Constants.Popup.separatorHeight))
        
        let button = NSButtonWithPadding()
        button.frame = CGRect(x: view.frame.width - 18, y: 6, width: 18, height: 18)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imageScaling = NSImageScaling.scaleAxesIndependently
        button.contentTintColor = .lightGray
        button.action = #selector(self.refreshPublicIP)
        button.target = self
        button.toolTip = localizedString("Refresh")
        button.image = Bundle(for: Module.self).image(forResource: "refresh")!
        
        row.addSubview(separatorView(localizedString("Public IP"), origin: NSPoint(x: 0, y: 0), width: self.frame.width))
        row.addSubview(button)
        
        container.addArrangedSubview(row)
        
        self.publicIPv4Field = popupRow(container, title: "\(localizedString("v4")):", value: localizedString("Unknown")).1
        self.publicIPv6Field = popupRow(container, title: "\(localizedString("v6")):", value: localizedString("Unknown")).1
        
        self.publicIPv4Field?.isSelectable = true
        if let valueView = self.publicIPv6Field {
            valueView.isSelectable = true
            valueView.font = NSFont.systemFont(ofSize: 10, weight: .regular)
            valueView.setFrameOrigin(NSPoint(x: valueView.frame.origin.x, y: 1))
        }
        
        view.addSubview(container)
        
        let h = container.arrangedSubviews.map({ $0.bounds.height }).reduce(0, +)
        view.setFrameSize(NSSize(width: self.frame.width, height: h))
        container.setFrameSize(NSSize(width: self.frame.width, height: view.bounds.height))
        view.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        container.heightAnchor.constraint(equalToConstant: view.bounds.height).isActive = true
        
        self.publicIPStackView = view
        
        return view
    }
    
    private func initProcesses() -> NSView {
        if self.numberOfProcesses == 0 {
            let v = NSView()
            self.processesView = v
            return v
        }
        
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: self.processesHeight))
        let separator = separatorView(localizedString("Top processes"), origin: NSPoint(x: 0, y: self.processesHeight-Constants.Popup.separatorHeight), width: self.frame.width)
        let container: ProcessesView = ProcessesView(
            frame: NSRect(x: 0, y: 0, width: self.frame.width, height: separator.frame.origin.y),
            values: [(localizedString("Downloading"), self.downloadColor), (localizedString("Uploading"), self.uploadColor)],
            n: self.numberOfProcesses
        )
        self.processes = container
        view.addSubview(separator)
        view.addSubview(container)
        self.processesView = view
        return view
    }
    
    // MARK: - callbacks
    
    public func numberOfProcessesUpdated() {
        if self.processes?.count == self.numberOfProcesses { return }
        
        DispatchQueue.main.async(execute: {
            self.processesView?.removeFromSuperview()
            self.processesView = nil
            self.processes = nil
            self.addArrangedSubview(self.initProcesses())
            self.processesInitialized = false
            self.recalculateHeight()
        })
    }
    
    public func usageCallback(_ value: Network_Usage) {
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.initialized {
                self.uploadValue = value.bandwidth.upload
                self.downloadValue = value.bandwidth.download
                self.setUploadDownloadFields()
                
                self.totalUploadField?.stringValue = Units(bytes: value.total.upload).getReadableMemory()
                self.totalDownloadField?.stringValue = Units(bytes: value.total.download).getReadableMemory()
                
                let form = DateComponentsFormatter()
                form.maximumUnitCount = 2
                form.unitsStyle = .full
                form.allowedUnits = [.day, .hour, .minute]
                
                if let duration = form.string(from: self.lastReset, to: Date()) {
                    self.totalUploadLabel?.toolTip = localizedString("Last reset", duration)
                    self.totalDownloadLabel?.toolTip = localizedString("Last reset", duration)
                }
                
                if let interface = value.interface {
                    self.interfaceField?.stringValue = "\(interface.displayName) (\(interface.BSDName))"
                    self.macAddressField?.stringValue = interface.address
                } else {
                    self.interfaceField?.stringValue = localizedString("Unknown")
                    self.macAddressField?.stringValue = localizedString("Unknown")
                }
                
                if value.connectionType == .wifi {
                    self.ssidField?.stringValue = value.wifiDetails.ssid ?? localizedString("Unknown")
                    if let v = value.wifiDetails.RSSI {
                        self.ssidField?.stringValue += " (\(v))"
                    }
                    var rssi = localizedString("Unknown")
                    if let v = value.wifiDetails.RSSI {
                        rssi = "\(v) dBm"
                    }
                    var noise = localizedString("Unknown")
                    if let v = value.wifiDetails.noise {
                        noise = "\(v) dBm"
                    }
                    var txRate = localizedString("Unknown")
                    if let v = value.wifiDetails.transmitRate {
                        txRate = "\(v) Mbps"
                    }
                    
                    self.standardField?.stringValue = value.wifiDetails.standard ?? localizedString("Unknown")
                    self.channelField?.stringValue = value.wifiDetails.channel ?? localizedString("Unknown")
                    
                    let number = value.wifiDetails.channelNumber ?? localizedString("Unknown")
                    let band = value.wifiDetails.channelBand ?? localizedString("Unknown")
                    let width = value.wifiDetails.channelWidth ?? localizedString("Unknown")
                    self.channelField?.toolTip = "RSSI: \(rssi)\nNoise: \(noise)\nChannel number: \(number)\nChannel band: \(band)\nChannel width: \(width)\nTransmit rate: \(txRate)"
                } else {
                    self.ssidField?.stringValue = localizedString("Unavailable")
                    self.standardField?.stringValue = localizedString("Unavailable")
                    self.channelField?.stringValue = localizedString("Unavailable")
                }
                
                if let view = self.publicIPv4Field, view.stringValue != value.raddr.v4 {
                    if let addr = value.raddr.v4 {
                        view.stringValue = (value.wifiDetails.countryCode != nil) ? "\(addr) (\(value.wifiDetails.countryCode!))" : addr
                    } else {
                        view.stringValue = localizedString("Unknown")
                    }
                }
                if let view = self.publicIPv6Field, view.stringValue != value.raddr.v6 {
                    if let addr = value.raddr.v6 {
                        view.stringValue = addr
                    } else {
                        view.stringValue = localizedString("Unknown")
                    }
                }
                
                if self.localIPField?.stringValue != value.laddr {
                    self.localIPField?.stringValue = value.laddr ?? localizedString("Unknown")
                }
                
                self.statusField?.stringValue = localizedString(value.status ? "UP" : "DOWN")
                
                self.initialized = true
            }
            
            if let chart = self.chart {
                if chart.base != self.base {
                    chart.base = self.base
                }
                chart.addValue(upload: Double(value.bandwidth.upload), download: Double(value.bandwidth.download))
            }
        })
    }
    
    public func connectivityCallback(_ value: Network_Connectivity?) {
        if self.latency.count >= 90 {
            self.latency.remove(at: 0)
        }
        self.latency.append(value?.latency ?? 0)
        
        DispatchQueue.main.async(execute: {
            if (self.window?.isVisible ?? false) || !self.connectionInitialized {
                var text = "Unknown"
                if let v = value {
                    text = v.status ? "UP" : "DOWN"
                }
                self.connectivityField?.stringValue = localizedString(text)
                if !self.latency.isEmpty {
                    self.latencyField?.stringValue = "\((self.latency.reduce(0, +) / Double(self.latency.count)).rounded(toPlaces: 2)) ms"
                }
                self.connectionInitialized = true
            }
            
            if let value, let chart = self.connectivityChart {
                chart.addValue(value.status)
            }
        })
    }
    
    public func processCallback(_ list: [Network_Process]) {
        DispatchQueue.main.async(execute: {
            if !(self.window?.isVisible ?? false) && self.processesInitialized {
                return
            }
            let list = list.map{ $0 }
            if list.count != self.processes?.count { self.processes?.clear() }
            
            for i in 0..<list.count {
                let process = list[i]
                let upload = Units(bytes: Int64(process.upload)).getReadableSpeed(base: self.base)
                let download = Units(bytes: Int64(process.download)).getReadableSpeed(base: self.base)
                self.processes?.set(i, process, [download, upload])
            }
            
            self.processesInitialized = true
        })
    }
    
    public func resetConnectivityView() {
        self.connectivityField?.stringValue = localizedString("Unknown")
    }
    
    // MARK: - Settings
    
    public override func settings() -> NSView? {
        let view = SettingsContainerView()
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Color of upload"), component: selectView(
                action: #selector(self.toggleUploadColor),
                items: Color.allColors,
                selected: self.uploadColorState.key
            )),
            PreferencesRow(localizedString("Color of download"), component: selectView(
                action: #selector(self.toggleDownloadColor),
                items: Color.allColors,
                selected: self.downloadColorState.key
            ))
        ]))
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Reverse order"), component: switchView(
                action: #selector(self.toggleReverseOrder),
                state: self.reverseOrderState
            ))
        ]))
        
        self.chartPrefSection = PreferencesSection([
            PreferencesRow(localizedString("Main chart scaling"), component: selectView(
                action: #selector(self.toggleChartScale),
                items: Scale.allCases,
                selected: self.chartScale.key
            )),
            PreferencesRow(localizedString("Scale value"), component: {
                let view: NSStackView = NSStackView()
                view.orientation = .horizontal
                view.spacing = 2
                let valueField = StepperInput(self.chartFixedScale, range: NSRange(location: 1, length: 1023))
                valueField.callback = self.toggleFixedScale
                valueField.widthAnchor.constraint(equalToConstant: 80).isActive = true
                view.addArrangedSubview(NSView())
                view.addArrangedSubview(valueField)
                view.addArrangedSubview(selectView(
                    action: #selector(self.toggleUploadScaleSize),
                    items: SizeUnit.allCases,
                    selected: self.chartFixedScaleSize.key
                ))
                return view
            }())
        ])
        view.addArrangedSubview(self.chartPrefSection!)
        self.chartPrefSection?.toggleVisibility(1, newState: self.chartScale == .fixed)
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Public IP"), component: switchView(
                action: #selector(self.togglePublicIP),
                state: self.publicIPState
            ))
        ]))
        
        return view
    }
    
    @objc private func toggleUploadColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let newValue = Color.allColors.first(where: { $0.key == key }) else {
            return
        }
        self.uploadColorState = newValue
        Store.shared.set(key: "\(self.title)_uploadColor", value: key)
        if let color = newValue.additional as? NSColor {
            self.processes?.setColor(1, color)
            self.uploadColorView?.layer?.backgroundColor = color.cgColor
            self.uploadStateView?.setColor(color)
            self.chart?.setColors(out: color)
        }
    }
    @objc private func toggleDownloadColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let newValue = Color.allColors.first(where: { $0.key == key }) else {
            return
        }
        self.downloadColorState = newValue
        Store.shared.set(key: "\(self.title)_downloadColor", value: key)
        if let color = newValue.additional as? NSColor {
            self.processes?.setColor(0, color)
            self.downloadColorView?.layer?.backgroundColor = color.cgColor
            self.downloadStateView?.setColor(color)
            self.chart?.setColors(in: color)
        }
    }
    @objc private func toggleReverseOrder(_ sender: NSControl) {
        self.reverseOrderState = controlState(sender)
        self.chart?.setReverseOrder(self.reverseOrderState)
        Store.shared.set(key: "\(self.title)_reverseOrder", value: self.reverseOrderState)
        self.display()
    }
    @objc private func toggleChartScale(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let value = Scale.allCases.first(where: { $0.key == key }) else { return }
        self.chartScale = value
        self.chart?.setScale(self.chartScale, Double(self.chartFixedScaleSize.toBytes(self.chartFixedScale)))
        self.chartPrefSection?.toggleVisibility(1, newState: self.chartScale == .fixed)
        Store.shared.set(key: "\(self.title)_chartScale", value: key)
        self.display()
    }
    @objc private func togglePublicIP(_ sender: NSControl) {
        self.publicIPState = controlState(sender)
        Store.shared.set(key: "\(self.title)_publicIP", value: self.publicIPState)
        
        DispatchQueue.main.async(execute: {
            if !self.publicIPState {
                self.publicIPStackView?.removeFromSuperview()
            } else if let view = self.publicIPStackView {
                self.insertArrangedSubview(view, at: 4)
            }
            self.recalculateHeight()
        })
    }
    @objc private func toggleFixedScale(_ newValue: Int) {
        self.chart?.setScale(self.chartScale, Double(self.chartFixedScaleSize.toBytes(newValue)))
        Store.shared.set(key: "\(self.title)_chartFixedScale", value: newValue)
    }
    @objc private func toggleUploadScaleSize(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let value = SizeUnit.allCases.first(where: { $0.key == key }) else { return }
        self.chartFixedScaleSize = value
        self.chart?.setScale(self.chartScale, Double(self.chartFixedScaleSize.toBytes(self.chartFixedScale)))
        Store.shared.set(key: "\(self.title)_chartFixedScaleSize", value: key)
        self.display()
    }
    
    // MARK: - helpers
    
    private func topValueView(_ view: NSView, title: String, color: NSColor) -> (NSView, NSTextField, NSTextField, ColorView) {
        let topHeight: CGFloat = 30
        let titleHeight: CGFloat = 15
        
        let valueWidth = "0".widthOfString(usingFont: .systemFont(ofSize: 26, weight: .light)) + 5
        let unitWidth = "KB/s".widthOfString(usingFont: .systemFont(ofSize: 13, weight: .light)) + 5
        let topPartWidth = valueWidth + unitWidth
        
        let topView: NSView = NSView(frame: NSRect(
            x: (view.frame.width-topPartWidth)/2,
            y: (view.frame.height - topHeight - titleHeight)/2 + titleHeight,
            width: topPartWidth,
            height: topHeight
        ))
        
        let valueField = LabelField(frame: NSRect(x: 0, y: 0, width: valueWidth, height: 30), "0")
        valueField.font = NSFont.systemFont(ofSize: 26, weight: .light)
        valueField.textColor = .textColor
        valueField.alignment = .right
        
        let unitField = LabelField(frame: NSRect(x: valueField.frame.width, y: 4, width: unitWidth, height: 15), "KB/s")
        unitField.font = NSFont.systemFont(ofSize: 13, weight: .light)
        unitField.textColor = .labelColor
        unitField.alignment = .left
        
        let titleWidth: CGFloat = title.widthOfString(usingFont: NSFont.systemFont(ofSize: 12, weight: .regular))+8
        let iconSize: CGFloat = 12
        let bottomWidth: CGFloat = titleWidth+iconSize
        let bottomView: NSView = NSView(frame: NSRect(
            x: (view.frame.width-bottomWidth)/2,
            y: topView.frame.origin.y - titleHeight,
            width: bottomWidth,
            height: titleHeight
        ))
        
        let colorBlock: ColorView = ColorView(frame: NSRect(x: 0, y: 1, width: iconSize, height: iconSize), color: color, radius: 4)
        let titleField = LabelField(frame: NSRect(x: iconSize, y: 0, width: titleWidth, height: titleHeight), title)
        titleField.alignment = .center
        
        topView.addSubview(valueField)
        topView.addSubview(unitField)
        
        bottomView.addSubview(colorBlock)
        bottomView.addSubview(titleField)
        
        view.addSubview(topView)
        view.addSubview(bottomView)
        
        return (topView, valueField, unitField, colorBlock)
    }
    
    private func setUploadDownloadFields() {
        let upload = Units(bytes: self.uploadValue).getReadableTuple(base: self.base)
        let download = Units(bytes: self.downloadValue).getReadableTuple(base: self.base)
        
        var valueWidth = "\(upload.0)".widthOfString(usingFont: .systemFont(ofSize: 26, weight: .light)) + 5
        var unitWidth = upload.1.widthOfString(usingFont: .systemFont(ofSize: 13, weight: .light)) + 5
        var topPartWidth = valueWidth + unitWidth
        
        self.uploadView?.setFrameSize(NSSize(width: topPartWidth, height: self.uploadView!.frame.height))
        self.uploadView?.setFrameOrigin(NSPoint(x: ((self.frame.width/2)-topPartWidth)/2, y: self.uploadView!.frame.origin.y))
        
        self.uploadValueField?.setFrameSize(NSSize(width: valueWidth, height: self.uploadValueField!.frame.height))
        self.uploadValueField?.stringValue = "\(upload.0)"
        self.uploadUnitField?.setFrameSize(NSSize(width: unitWidth, height: self.uploadUnitField!.frame.height))
        self.uploadUnitField?.setFrameOrigin(NSPoint(x: self.uploadValueField!.frame.width, y: self.uploadUnitField!.frame.origin.y))
        self.uploadUnitField?.stringValue = upload.1
        
        valueWidth = "\(download.0)".widthOfString(usingFont: .systemFont(ofSize: 26, weight: .light)) + 5
        unitWidth = download.1.widthOfString(usingFont: .systemFont(ofSize: 13, weight: .light)) + 5
        topPartWidth = valueWidth + unitWidth
        
        self.downloadView?.setFrameSize(NSSize(width: topPartWidth, height: self.downloadView!.frame.height))
        self.downloadView?.setFrameOrigin(NSPoint(x: ((self.frame.width/2)-topPartWidth)/2, y: self.downloadView!.frame.origin.y))
        
        self.downloadValueField?.setFrameSize(NSSize(width: valueWidth, height: self.downloadValueField!.frame.height))
        self.downloadValueField?.stringValue = "\(download.0)"
        self.downloadUnitField?.setFrameSize(NSSize(width: unitWidth, height: self.downloadUnitField!.frame.height))
        self.downloadUnitField?.setFrameOrigin(NSPoint(x: self.downloadValueField!.frame.width, y: self.downloadUnitField!.frame.origin.y))
        self.downloadUnitField?.stringValue = download.1
        
        self.uploadStateView?.setState(self.uploadValue != 0)
        self.downloadStateView?.setState(self.downloadValue != 0)
    }
    
    @objc private func refreshPublicIP() {
        NotificationCenter.default.post(name: .refreshPublicIP, object: nil, userInfo: nil)
    }
    
    @objc private func resetTotalNetworkUsage() {
        NotificationCenter.default.post(name: .resetTotalNetworkUsage, object: nil, userInfo: nil)
        self.lastReset = Date()
    }
    
    @objc private func resetTotalNetworkUsageCallback() {
        self.lastReset = Date()
    }
}
