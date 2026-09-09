# POSSESS 애셋 연결 규약

판정 ID와 충돌 크기는 아트 교체로 바꾸지 않는다. 모델 연결은 `scripts/visuals.gd`, UI 그림 연결은 `scripts/ui_art.gd`가 담당한다.

## 3D 모델

- 안정적인 역할 ID: `soldier`, `brute`, `shotgun`, `archer`, `mage`, `storm`.
- `Visuals.MODELS[id]`: `path`는 프로젝트 내 PackedScene/GLB 경로, `scale`은 모델 자식에만 적용할 균일 배율이다.
- `idle`, `walk`, `attack`은 모델 내부 AnimationPlayer에 존재하는 정확한 클립 이름이다. 루프와 전환은 presentation이 담당한다.
- Godot 단위는 미터, +Y가 위다. 원점은 발바닥 중심으로 유지한다. 현 모델 방향은 기존 파일을 기준으로 유지한다.
- 현재 Rogue/Mage는 0.79, Warrior는 산탄병 0.79 / 망치병 0.88. 보스 외형 배율은 `Visuals.BOSS_SCALE` 1.4로 이전 값과 같다.
- 교체 후 `tests/ui.gd`로 모든 모델·클립 로딩을 검사한다. 콜라이더·피해·이동·빙의 확률은 이 표에 넣지 않는다.

## UI 그림

정확한 경로·표시 크기는 [ART_SLOTS.md](docs/ui/ART_SLOTS.md)를 따른다. 그림은 현재 모두 비어 있는 TextureRect다. PNG를 정해진 위치에 넣고 Godot 임포트 후 게임을 다시 시작하면 자동 연결된다. 누락 파일은 오류 없이 빈칸으로 유지한다. 텍스트와 키 표시를 이미지에 굽지 않는다.

## 글꼴과 번역

- 단일 테마: `theme/possess.tres`. 색은 `Palette`, 글자 위계·패널·버튼·막대는 같은 Theme의 variation으로 정의한다. 화면별 테마나 시스템 폰트를 추가하지 않는다.
- 글꼴: `assets/fonts/NotoSansKR.ttf`, SIL OFL 1.1은 같은 폴더 `OFL.txt`. 원본 [Google Fonts](https://github.com/google/fonts/tree/main/ofl/notosanskr). 굵기 축은 450(본문), 760(강조). 시스템 fallback은 꺼져 있다.
- `locale/ko.csv`: `keys,ko,en`. 영어 열은 의도적으로 비웠다. Godot는 빈 언어 리소스를 만들지 않으므로 현재 프로젝트에는 ko 번역만 등록하고 fallback도 ko로 설정했다. 영어가 채워지면 임포트 후 `ko.en.translation`을 프로젝트 번역 목록에 추가한다.
- 화면 고정 문구는 `tr(KEY)`, 기존 판정 데이터의 이름·설명은 `ui_text.gd`의 `DATA_*` 키를 통해 번역한다. 판정 데이터 자체는 수정하지 않는다. 런타임 locale 전환은 표시 어댑터가 감지해 기존 Control을 갱신한다.
- 동적 수치는 번역 문자열의 `%d`, `%.1f`, `%s`에 대입한다. 번역 시 자리표시자 개수와 타입을 유지한다.

## 표시 계층

`authority.feedback → ui_presenter → snapshot/toast/impact 신호 → hud → 네 Control 씬`.
연속 상태는 기존 판정 계층에 변경 신호가 없어 읽기 전용 presenter가 샘플링한다. UI 씬에는 authority 참조가 없다. 버튼은 기존 main 입력 처리로 의도만 전달한다. 판정 계층에는 새 신호나 UI 코드를 추가하지 않는다.
