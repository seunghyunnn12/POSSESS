# 실험판 0.2 검증 기록

2026-09-08 / Windows / Godot 4.7.1 stable. 이전 M0 검증은 `QA.md`에 보존합니다.

## 기능 검증

총 **124개 검사 통과**, 실패 0개.

- `tests/smoke.gd`: 기존 전투 회귀 47개. 비교용 일반 개체와 증강 비활성 조건에서 원래 이동·피해·빙의·부패·재시작을 검증합니다.
- `tests/evolution.gd`: 실제 그래픽 창에서 확장 기능 77개. 특별 개체의 저항, 약화 공식, 개체 수치 범위, 몸의 특성 복사/교체, 위장과 첫 공격, 감시자의 시야·벽·탐지 시간을 검증합니다.
- 개봉의 유지/취소, 사용 횟수 제한과 수명 상한, 처치·빙의 보상 중복 방지, 경험치 초과분과 다중 레벨업, 실제 증강 효과, 마지막 폭발·선택·클리어 순서를 검증합니다.
- 메뉴의 시간/애니메이션 정지, Esc 위에 열린 선택의 유지, 숫자키와 클릭 선택, 960×540 창의 클릭 좌표, 메뉴 클릭 관통 방지와 클릭을 뗀 뒤 공격 재개를 검증합니다.
- 증강은 권위 노드만 적용할 수 있고, 완료한 선택을 다시 적용하거나 2단계 상한을 넘어 반복 획득할 수 없습니다.

최종 로그: `qa-output/smoke.log`, `qa-output/evolution-rendered.log`. 마지막 수정 후 렌더링 검증 로그: `qa-output/visual-v02.log`. 이 로그들에는 스크립트 오류나 연출 재개 오류가 없습니다.

## 자동 플레이

`tests/playthrough.gd`는 일반 이동·공격·빙의와 증강 선택 입력으로 플레이합니다. 위치·체력·빙의 결과·무적 시간을 강제로 바꾸지 않습니다.

- 일반 플레이 기록: **5회 빙의, 클리어, 9.48초**. 특별 개체에 대한 빙의 실패와 재시도 포함.
- 자연 부패 플레이 기록: **3회 자연 만료·폭발·유령 복귀, 4회 빙의, 1회 처치, 클리어, 113.85초**.
- 시간은 `--fixed-fps 60`으로 가속한 게임 내 시간입니다. 이는 재미·사람의 반응 속도·평균 클리어 시간에 대한 측정이 아닙니다. 무작위 증강 제안에 따라 다음 실행의 경로와 시간은 달라질 수 있습니다.

## 화면과 성능

타이틀, 유령, 병사, 부패, 브루트, 특별 개체, 몸 정보창, 증강 카드, 선택 중 Esc 정보창, 전투 화면을 캡처해 확인했습니다.

- `qa-output/09-host-inspector.png`: 현재 몸의 특성, 실제 능력치, 개체 수치와 유령 증강.
- `qa-output/10-upgrade-choice.png`: 선택 카드와 적용 후 누적 효과.
- `qa-output/11-inspector-over-choice.png`: 선택을 보류하고 몸 정보를 확인하는 화면.

AMD Radeon RX 580 2048SP / 1280×720 / Compatibility(OpenGL) / 수직 동기화 환경에서, 적 5명 AI와 연속 발사가 동작하는 12초 구간을 측정했습니다.

| 항목 | 마지막 측정 |
|---|---:|
| 프레임 | 720 |
| 평균 | 59.9 fps / 16.69ms |
| 프레임 시간 p95 | 18.13ms |
| 프레임 시간 p99 | 19.55ms |

평균은 약 60fps이며 일부 프레임은 16.67ms를 넘습니다. 다른 해상도나 장시간 실행까지 보장하지 않습니다. 성능 측정에서만 테스트가 끝날 때까지 소멸과 무적 시간을 유지하며, 입력 자동 플레이에서는 사용하지 않습니다.

## 다시 실행

프로젝트 루트의 PowerShell에서 실행합니다. 그래픽 검증은 임시 게임 창을 띄우고 종료합니다.

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/smoke.gd --log-file ./qa-output/smoke.log
Godot_v4.7.1-stable_win64_console.exe --path . --script res://tests/evolution.gd --log-file ./qa-output/evolution-rendered.log
Godot_v4.7.1-stable_win64_console.exe --headless --fixed-fps 60 --path . --script res://tests/playthrough.gd --log-file ./qa-output/playthrough-v02.log
Godot_v4.7.1-stable_win64_console.exe --headless --fixed-fps 60 --path . --script res://tests/playthrough.gd --log-file ./qa-output/playthrough-decay-v02.log -- --decay
Godot_v4.7.1-stable_win64_console.exe --path . --script res://tests/visual.gd --resolution 1280x720 --log-file ./qa-output/visual-v02.log
```

## 남은 플레이 평가

이 버전은 방 하나와 적 5명으로 시스템 간 연결을 검증합니다. 특별 개체의 실패 부담이 보상에 비해 적절한지, 위장 시간을 보급·자리 잡기에 쓰게 되는지, 증강 선택이 실제 몸 선택을 바꾸는지는 사람의 플레이로 조정해야 합니다. 개체 영구 수집, 특성 계승, 다음 방과 보스는 포함하지 않았습니다.
