# Astra 과제서 — M1: UI 시각 패스 (실제 게임처럼 보이게)

기준: `docs/ui/UI_STYLE.md`(토큰·폰트·규칙) + `docs/ui/*.dc.html`(화면별 목업 — HTML 안의 px·색·폰트 값이 스펙). 이 과제 밖의 새 시스템·콘텐츠·규칙 추가 금지. 판정 계층(authority/action)은 손대지 않는다.

## 1. 폰트·테마
- Google Fonts에서 Cinzel(600·800), Noto Serif KR(700·900), Noto Sans KR(400·500·700) TTF를 받아 `theme/fonts/`에 동봉(OFL 라이선스 텍스트 포함).
- `theme/possess.tres` Theme 리소스 하나에 UI_STYLE.md의 색 토큰·타입 스케일·패널 스타일(StyleBoxFlat, 모서리 0, 1px 테두리)을 정의. 모든 UI는 이 Theme만 쓴다.

## 2. 화면 4종을 Control 씬으로 재구축 (목업과 픽셀 단위로 맞출 것)
- `scenes/ui/hud.tscn` ← `docs/ui/Main.dc.html`
- `scenes/ui/upgrade_cards.tscn` ← `docs/ui/UpgradeCards.dc.html`
- `scenes/ui/title.tscn` ← `docs/ui/Title.dc.html`
- `scenes/ui/pause_info.tscn` ← `docs/ui/PauseInfo.dc.html`
- 기존 `hud.gd`/`action_hud.gd`의 `draw_string` 즉시 모드는 제거. UI는 authority 신호만 관찰.
- 아이콘·초상화·카드 일러스트·키아트 자리는 `TextureRect`(placeholder 색 사각형)로 비워 둔다 — 이미지 파일만 넣으면 되도록.
- 조준점·빙의 확률 호·회피 쿨다운 호는 `_draw`가 아닌 Control(TextureProgressBar 또는 작은 커스텀 Control) 로.

## 3. 정보 정리 (목업의 HUD 규칙)
- 상시 노출 텍스트는 HUD 4곳(스테이지·남은 적·몸/수명·무기/탄창) + 하단 영혼 바만.
- 같은 안내가 두 번 뜨지 않는다(무기 팁 중앙·하단 중복 제거). "위장 · 공격하면 풀립니다" 같은 상시 문구 제거.
- 상태 변화 안내는 1.5초 토스트 1줄, 한 번에 하나(큐).
- 수명 바 10칸 분절, 25% 이하 danger 색.

## 4. 같이 처리 (UI 만드는 김에, 화면에 안 보이는 배선)
- 화면 문자열 전부 `tr("KEY")` + `locale/ko.csv`(영어 열은 비워 둠 — 별도 담당).
- 모델 경로·스케일·애니 클립 이름을 `scripts/visuals.gd` 테이블 하나로 이동(하드코딩 제거). 규약은 `ASSET_CONVENTIONS.md`에 문서화.

## 수용 기준
1. 목업 4장과 게임 스크린샷 4장을 나란히 놓았을 때 레이아웃·색·폰트·크기가 일치한다. `qa-output/v06-*.png`로 제출.
2. `draw_string` 직접 호출이 남아 있지 않다.
3. 기존 검사 261개 통과 + 언어 전환·테이블 로딩 검사 추가. 성능 회귀 없음(같은 장면 p99).
4. 상시 텍스트가 HUD 4곳+영혼 바 외에 없다.
5. 작업 단위별 커밋, `git push origin main`, 결과는 `QA_V06.md`.

## 이후 예정 (지금 하지 말 것)
M2 영구 해금·세이브·유령 3종·설정 메뉴 / M3 60fps·Windows 빌드·Steamworks / 아트 패스(AI 3D 모델·애니·환경·VFX·사운드) / M4 협동.
