# 0.6 UI 시각 패스

## 디자인 의도

1. HUD는 청록 프레임의 몸·수명 → 무기·탄창 → 구역·남은 적 순서로 읽히며, 중앙은 조준과 전투에 비워 둔다.
2. 타이틀은 큰 POSSESS 제목과 황동색 시작 버튼이 중심이고, 오른쪽 세로 프레임은 향후 키아트 전용 공간이다.
3. 증강은 현재 포커스의 황동 테두리와 청록 효과 수치가 먼저 보이고, 이름·설명·조합 조건이 그 뒤를 따른다.
4. 정보창은 현재 몸의 이름·특성·수치를 중심으로 두고, 원정 기록과 조작은 탭으로 분리한다. 그림은 지정된 빈 슬롯에만 들어간다.
5. 짙은 청회색은 배경, 청록은 몸과 상호작용, 황동색은 선택, 연보라는 성장, 적색은 위험. OFL Noto Sans KR 450/760은 한영 위계와 작은 글자 가독성을 함께 유지한다.

## 제출 화면

| 화면 | 파일 |
|---|---|
| 타이틀 | [v06-title.png](qa-output/v06-title.png) |
| 전투 HUD | [v06-hud.png](qa-output/v06-hud.png) |
| 증강 선택 | [v06-augment.png](qa-output/v06-augment.png) |
| 일시정지·몸 정보 | [v06-pause.png](qa-output/v06-pause.png) |
| 추가: 원정 기록 / 문 상호작용 | [v06-journal.png](qa-output/v06-journal.png), [v06-door.png](qa-output/v06-door.png) |

아트는 요청대로 모두 빈 TextureRect다. 스크린샷은 실제 Godot 창에서 촬영했다. HUD 예시는 기존 산탄병의 몸·상층 회랑을 사용하는 고정 QA 상태이며 새로운 콘텐츠를 추가한 것이 아니다.

## 검사

| 검사 | 결과 | 근거 |
|---|---:|---|
| 기존 smoke | 47 / 47 | `qa-output/v06-smoke.log` |
| 기존 evolution | 75 / 75 + 실제 창 입력 2 / 2 | `qa-output/v06-evolution.log`, `v06-evolution-render.log` |
| 기존 journey | 28 / 28 | `qa-output/v06-journey.log` |
| 기존 campaign | 70 / 70 | `qa-output/v06-campaign.log` |
| 기존 action + 직전 문 수정 회귀 | 50 / 50 | `qa-output/v06-action.log` |
| UI·언어·폰트·모델 테이블 | 41 / 41 | `qa-output/v06-ui.log` |

요청한 기존 261개에 직전 문 회귀 9개, 실제 창 입력 2개, 이번 UI 검사 41개를 더해 **313개 고유 검사 통과**. UI 검사는 ko/en/ko 런타임 전환, 빈 영어 열의 한국어 fallback, 모든 CSV 문자의 폰트 글리프, 시스템 fallback 비활성화, 모든 모델·애니 클립 로딩, 빈 그림 슬롯 10개, 클릭·일시정지·Tab·문 진행 표시, HUD 상시 텍스트 영역과 실제 시간 1.5초 단일 토스트를 포함한다.

`scripts/authority.gd`, `action.gd`, `journey.gd`, `campaign.gd`는 작업 전 `b787755`와 동일하다. UI는 기존 피드백 신호와 읽기 전용 표시 어댑터를 사용한다. `hud.gd`와 `action_hud.gd`의 즉시 모드 텍스트를 제거했고, 프로젝트 스크립트에 `draw_string`/`draw_multiline_string` 직접 호출이나 SystemFont 생성은 없다. 시스템 폰트 fallback도 끄고 번들 TTF만 쓴다.

상시 HUD 문구는 구역·남은 적·몸/수명·무기/탄창 네 영역과 영혼 바에만 있다. 문/상자/비밀 안내는 가까이서 상호작용 가능한 동안만 나타나는 한 슬롯을 공유한다. 조준 대상의 월드 라벨과 감시자 몸의 영혼 시야는 기존 전투 기능으로 유지한다.

## 성능 비교

RX 580 2048SP, Compatibility, 1280×720, VSync, 동일한 8적(보스 포함)·상층 회랑·화염/서리/번개 투사체 장면. 3초 워밍업 후 15초 동안 `RenderingServer.frame_post_draw`로 측정했고 다른 QA 게임 프로세스와 병렬 실행하지 않았다.

| 측정 | 프레임 수 | 평균 ms / FPS | p95 ms | p99 ms |
|---|---:|---:|---:|---:|
| 교체 전 | 900 | 16.68 / 59.9 | 17.36 | 18.88 |
| 교체 후 1회 | 902 | 16.64 / 60.1 | 18.09 | 19.05 |
| 교체 후 확인 반복 | 900 | 16.68 / 59.9 | 16.99 | 17.21 |

평균 프레임은 유지됐다. 첫 측정의 p99 +0.17ms 차이는 반복되지 않았고, 이 동일 장면에서는 지속적인 성능 회귀가 확인되지 않았다. 이는 현재 테스트 장면의 결과이며 이후 아트의 성능을 보증하는 수치는 아니다. 세 보고서를 모두 보존했다: `v06-baseline-performance.txt`, `v06-performance.txt`, `v06_repeat-performance.txt`.

## 재현과 인계

Godot 4.7.1에서 최초 임포트 후 `--path . --script res://tests/ui.gd`로 화면과 UI 검사를 재생성한다. 나머지는 해당 `tests/*.gd`를 같은 방식으로 실행한다. 실제 마우스 입력 검사는 headless 없이 실행한다.

성능 결과를 별도 파일로 남기려면 `--path . --script res://tests/performance_action.gd -- --report-prefix=v06`을 사용한다. 옵션을 생략하면 기존 v05 경로로 기록하므로 이전 검사와 호환된다.

그림 경로·크기: [ART_SLOTS.md](docs/ui/ART_SLOTS.md). 모델·폰트·번역 배선: [ASSET_CONVENTIONS.md](ASSET_CONVENTIONS.md). 영어 열은 비워 뒀고 영어 번역 담당자가 채운 뒤 리소스를 등록하면 된다. 디자인 참고 목업은 규격으로 사용하지 않았다.
