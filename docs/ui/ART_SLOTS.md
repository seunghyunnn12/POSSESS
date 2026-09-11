# 0.10 UI 아트 슬롯 / 2D 제작 브리프

1280×720 기준. 초상화·무기·증강 등 기존 13개 슬롯은 비어 있다. 0.10에서 사용자가 승인한 이야기·전환 연출에 한해 지하 종문 삽화를 제작했다. 프레임·문구·막대는 UI가 그리므로 그림에 포함하지 않는다.

| 용도 | 씬 / 노드 | 표시 크기(px) | 비율 | 자동 연결 경로 (`assets/ui/` 아래) |
|---|---|---:|---:|---|
| 출발·결과 삽화 | title / KeyArt | 506×640 | 253:320, COVERED | `illustrations/bell_gate.png` |
| 구역 전환 삽화 | passage / illustration | 1280×720 | 16:9, COVERED | `illustrations/bell_gate.png` |
| HUD 현재 몸 초상 | hud / Host/PortraitFrame/Portrait | 76×96 | 19:24 | `portraits/{role}.png` |
| 정보창 몸 초상 | pause / Body/Portrait | 278×358 | 139:179 | `portraits/{role}.png` |
| 구역 아이콘 | hud / Stage/Icon | 32×32 | 1:1 | `icons/stage.png` |
| 적 수 아이콘 | hud / Enemies/Icon | 28×28 | 1:1 | `icons/enemy.png` |
| 상호작용 아이콘 | hud / Interaction/Icon | 28×28 | 1:1 | `icons/interact.png` |
| 현재 무기 아이콘 | hud / Weapon/Icon | 48×48 | 1:1 | `weapons/{role}.png` |
| 증강 카드 그림 ×3 | augment / Card0..2/Art | 336×112 | 3:1 | `augments/{id}.png` |
| 시작 유령 초상 ×4 | title / GhostSelection/{ghost}/Portrait | 60×66 | 10:11 | `portraits/{ghost}.png` |

`role`: `soul`, `soldier`, `brute`, `shotgun`, `archer`, `mage`, `storm`. 몸 초상은 같은 원본을 두 슬롯에서 비율 유지하여 사용한다. **권장 원본은 556×716**, 얼굴·가슴 중심 실루엣을 중앙 80%에 두면 작은 HUD에서도 잘리지 않는다.

`ghost`: `wanderer`, `reaper`, `arcanist`, `gunslinger`. 유령 상태의 HUD·정보창 초상과 무기 슬롯도 각각 `portraits/{ghost}.png`, `weapons/{ghost}.png`를 사용한다. 시작 전에는 키아트 영역 대신 유령 선택 목록을 표시한다. 기존 `soul` 슬롯은 이전 규칙의 테스트 장면을 위한 예비 경로다.

`id`: `ambush`, `vigor`, `mercy`, `curse`, `rot`, `funeral`. 카드 원본은 1008×336 권장. 이름·수치·희귀도 테두리를 굽지 않는다.

키아트는 1012×1280 이상, 인물을 오른쪽에 배치하고 지하의 서늘한 공기와 빌린 몸의 실루엣으로 구성한다. 타이틀 문구는 슬롯 밖 왼쪽에 있다. 아이콘은 원본 96×96 이상, 투명 배경·굵은 실루엣·외곽 12% 안전 여백을 권장한다.

색 역할: 청록은 영혼/현재 몸과 상호작용, 황동색은 선택과 프레임, 연보라는 영혼 성장, 붉은색은 위험이다. 명도는 아이콘·인물 실루엣이 배경보다 높게, 프레임보다 지나치게 밝지 않게 한다.

그림을 추가한 뒤 Godot에서 임포트하고 재실행한다. `ui_art.gd`가 경로를 자동 해석하며 없는 그림에 임시 아이콘·생성 이미지를 끼워 넣지 않는다. 현재 파일 경로와 슬롯 크기는 위 표가 기준이다.
