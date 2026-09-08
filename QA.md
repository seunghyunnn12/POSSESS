# M0 검증 기록

검증일: 2026-09-08. Godot 4.7.1 stable / Windows / GDScript.

## 결과

- 실제 그래픽 창에서 통합 테스트 **47개 통과**, 실패 0개.
- 벽에 막히는 공격·빙의, 머리 충돌 판정, 적의 조준 사격과 회피, 빙의 성공·실패, 재장전, 브루트 피해 감소, 자연 부패·폭발·이탈, 사망·클리어, R 재시작, Esc 및 포커스 상실을 검증했습니다.
- 입력만 사용하는 자동 플레이: **5회 빙의 후 클리어**. 체력·위치·확률 결과를 강제 변경하지 않았습니다. RNG 시드는 재현을 위해 17로 고정했습니다.
- 자연 부패 자동 플레이: 게임 시간 **105.53초** 동안 몸의 자연 만료와 유령 복귀 **3회**, 빙의 **5회**, 최종 클리어. `--fixed-fps 60`으로 시간만 가속한 검증입니다.
- 실제 렌더러에서 타이틀·유령·병사·부패·브루트·일시정지·전투 화면을 캡처해 확인했습니다.

## 성능

AMD Radeon RX 580 2048SP, 1280×720, Compatibility/OpenGL, 60Hz 수직 동기화 환경.

적 5명 AI가 동작하고 연속 발사하는 12초 구간, 준비 프레임 제외:

| 항목 | 측정 |
|---|---:|
| 렌더링 프레임 | 720 |
| 평균 | 59.9 fps / 16.68ms |
| 프레임 시간 p95 | 16.96ms |
| 프레임 시간 p99 | 17.49ms |

이 구간에서는 약 60fps를 유지했습니다. 다른 기기, 해상도 및 장시간 실행까지 보장하는 결과는 아닙니다. 성능 스크립트에서만 지속 측정을 위해 소멸 시간과 무적 시간을 유지합니다. 입력 자동 플레이에서는 이 보정을 사용하지 않습니다.

## 재실행

프로젝트 루트의 PowerShell에서:

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/smoke.gd --log-file ./qa-output/smoke.log
Godot_v4.7.1-stable_win64_console.exe --path . --script res://tests/smoke.gd --log-file ./qa-output/smoke-rendered.log
Godot_v4.7.1-stable_win64_console.exe --headless --fixed-fps 60 --path . --script res://tests/playthrough.gd --log-file ./qa-output/playthrough.log
Godot_v4.7.1-stable_win64_console.exe --headless --fixed-fps 60 --path . --script res://tests/playthrough.gd --log-file ./qa-output/playthrough-decay.log -- --decay
Godot_v4.7.1-stable_win64_console.exe --path . --script res://tests/visual.gd --resolution 1280x720 --log-file ./qa-output/visual.log
```

로그·스크린샷·성능 원본은 `qa-output/`에 있습니다. `.gdignore`로 게임 에셋 임포트 대상에서 제외했습니다.

## 사람이 판단할 부분

첫 플레이에서 규칙을 스스로 발견하는지, 빙의 순간이 충분히 짜릿한지, 세 번 이상 반복하고 싶은지는 자동 테스트로 합격 판정하지 않았습니다. 완벽한 조준과 빠른 판단을 하는 자동 플레이는 7.67초 만에 다섯 몸을 갈아탈 수 있었습니다. 이는 기능 연결 검증이며 사람의 평균 클리어 시간이나 재미 측정값이 아닙니다.

추가 콘텐츠 대신 이 버전의 실제 첫 플레이를 보고 약화 피해량, 실패 부담, 부패 시간을 조정하는 것이 다음 우선순위입니다. 현재 수치는 과제서의 20초 소멸, 25/35초 부패 및 빙의 확률 공식을 유지합니다.
