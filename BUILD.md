# Windows 플레이테스트 빌드

최신 0.10: `./Build-Windows.ps1 -OutputDirectory builds/windows-v10`으로 기존 실행 파일을 덮지 않고 빌드한다. 배포 ZIP은 `builds/POSSESS-0.10-Windows.zip`이다. 아래 기본 출력 경로도 계속 지원한다.

`builds/windows/POSSESS.exe`와 같은 폴더의 `POSSESS.pck`가 실제 배포물이다. 편집기 없이 실행된다. ZIP을 풀고 EXE를 실행한다. 소스 저장소와 빌드 도구는 배포하지 않는다.

## 재현

Godot 4.7.1 콘솔 실행 파일이 PATH에 있는 Windows PowerShell에서:

```powershell
./Prepare-Windows.ps1
./Build-Windows.ps1
Compress-Archive -Path builds/windows/* -DestinationPath builds/POSSESS-0.9-Windows.zip -Force
```

준비 스크립트는 [공식 4.7.1 템플릿](https://github.com/godotengine/godot-builds/releases/tag/4.7.1-stable)을 내려받아 공식 SHA512 목록과 비교하고 Windows x86_64 템플릿만 추출한다. 다운로드는 약 1.2GiB다. `.build-tools`와 `builds`는 Git에서 제외한다. 최초 준비 후에는 빌드 스크립트만 실행하면 된다.

`export_presets.cfg`는 Windows 릴리스 템플릿, 외부 PCK, GDScript 바이트코드를 사용한다. 테스트·QA·문서·빌드 도구는 PCK에서 제외한다. 빌드 후 EXE·PCK의 SHA256과 엔진·글꼴·모델 라이선스를 동봉한다. Godot의 `COPYRIGHT.txt`는 엔진에 포함된 외부 라이브러리 고지를 포함한다.

## 현재 한계

이 기기의 RX 580 / Windows에서 시작·연습방·종료를 확인했다. 별도 깨끗한 PC, 다른 GPU, 장시간 완주까지 배포물로 검증한 것은 아니다. 코드 서명, 설치 프로그램, Steamworks, 스토어 업로드는 포함하지 않는다.

저장 경로 호환성을 위해 project.godot의 기존 config/name을 유지한다. 기존 개발 버전과 유령 해금·설정 파일을 공유한다. QA 스크립트는 실제 사용자 저장에 접근하지 않는다. 테스트용 .cfg 파일과 저장 파일은 배포물에 넣지 않는다.
