//
//  ControllerTests.swift
//  Tests
//
//  Created by 李文康 on 2023/11/20.
//  Copyright © 2023 Shanbay iOS. All rights reserved.
//

final class ControllerTests: QuickSpec {
    override func spec() {
        describe("Test player controller") {
            it("play") {
                waitUntil(timeout: .seconds(5)) { done in
                    let player = ZonPlayer
                        .player(self._url)
                        .onError(self) { wlf, _ in
                            wlf.__zon_triggerUnexpectedError()
                        }
                        .onPlayed(self) { _, payload in
                            expect { payload.1 } == 1
                            done()
                        }
                        .activate()
                    player.play()
                    self._players.append(player)
                }
            }

            it("pause") {
                waitUntil(timeout: .seconds(5)) { done in
                    let player = ZonPlayer
                        .player(self._url)
                        .onError(self) { wlf, _ in
                            wlf.__zon_triggerUnexpectedError()
                        }
                        .onPaused(self) { _, _ in
                            done()
                        }
                        .activate()
                    player.play()
                    player.pause()
                    self._players.append(player)
                }
            }

            it("Set playback rate") {
                waitUntil(timeout: .seconds(5)) { done in
                    let rate: Float = 1.5
                    let player = ZonPlayer
                        .player(self._url)
                        .onError(self) { wlf, _ in
                            wlf.__zon_triggerUnexpectedError()
                        }
                        .onRate(self) { _, payload in
                            expect { payload.1 } == 1
                            expect { payload.2 } == rate
                            done()
                        }
                        .activate()
                    player.setRate(rate)
                    self._players.append(player)
                }
            }

            it("Seek") {
                waitUntil(timeout: .seconds(5)) { done in
                    let time: TimeInterval = 3
                    let player = ZonPlayer
                        .player(self._url)
                        .onError(self) { wlf, _ in
                            wlf.__zon_triggerUnexpectedError()
                        }
                        .activate()
                    player.play()
                    player.seek(to: time) { _ in
                        expect { player.currentTime } == time
                        done()
                    }
                    self._players.append(player)
                }
            }

            it("Playback in background") {
                waitUntil(timeout: .seconds(5)) { done in
                    var status = [true, false]
                    let player = ZonPlayer
                        .player(self._url)
                        .onError(self) { wlf, _ in
                            wlf.__zon_triggerUnexpectedError()
                        }
                        .onBackground(self) { wlf, payload in
                            expect { status.isEmpty }.to(beFalse())
                            expect { status.removeFirst() } == payload.1
                            if status.isEmpty { done() }
                        }
                        .activate()
                    player.play()
                    player.enableBackgroundPlayback()
                    NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
                    NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
                    player.disableBackgroundPlayback()
                    NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
                    NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
                    self._players.append(player)
                }
            }
        }
    }

    private var _players: [ZonPlayable] = []
    private let _url = "https://media-audio1.baydn.com/creeper/listening/33aede75f51823e9f7242cc65d09bc45.8c3bc6434a2d9c9b61f7fe28b519a841.mp3"
}
