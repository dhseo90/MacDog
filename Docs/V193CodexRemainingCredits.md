# v1.9.3 Codex 잔여 크레딧

상태: 코드 완료. 릴리즈 순서는 [V193ReleaseReadiness.md](V193ReleaseReadiness.md)
작성일: 2026-10-01
대상 버전: `1.9.3`
기준 브랜치: `v1.9.3`
개발 검증 버전: `MACDOG_APP_VERSION=1.9.3`

버전 정책: minor 구간은 `0~9`까지만 사용한다. 현재 기능 버전은 `v1.9.3`이다.

## 목표

Codex 1번 탭에서 잔여 크레딧이 있으면 초기화권 아래에 보여 준다.
없는 항목은 칸을 남기지 않고 숨긴다. 화면은 스크롤 없이 한 페이지다.

잔여 크레딧과 초기화권은 다른 값이다.

| 항목 | 원천 | 화면 |
| --- | --- | --- |
| 잔여 크레딧 | `credits`의 `hasCredits`, `unlimited`, `balance` | 잔액. 만료일은 없다 |
| 초기화권 | `rateLimitResetCredits.availableCount` | 장수와 가장 빠른 만료 |

`balance`를 초기화권 장수로 쓰지 않는다.

## 화면

위에서 아래로 다음 순서를 유지한다.

1. 주간 그래프
2. 초기화권. `availableCount`가 0 이하이거나 없으면 숨긴다
3. 잔여 크레딧. 값이 없으면 숨긴다
4. 짧은 간격
5. 데이터 상태. 칼럼 바닥에 붙인다

잔여 크레딧 문구는 `잔여 크레딧`이다. 테두리와 글자 크기는 초기화권과 같다.

## 숫자

- 소수점은 반올림하지 않고 버린다. `12.9`는 `12`, `146.087`은 `146`이다.
- `hasCredits`가 참이고 잔액이 0이면 `0`을 보여 준다.
- `unlimited`는 `무제한`이다.
- 숫자가 아닌 잔액은 앞뒤 공백만 제거한다.

## 높이

남는 높이는 주간 그래프만 키운다. 카드 간격을 늘려 빈칸을 만들지 않는다.

- 초기화권과 잔여 크레딧이 둘 다 있으면 그래프의 최소 높이는 5시간 게이지가 있을 때 36, 주간만 있을 때 51이다.
- 항목이 하나면 기존 높이 56 또는 89를 유지한다.
- 둘 다 없으면 비는 높이도 그래프가 가져간다.
- Grok 주간 그래프 높이는 89로 유지한다. 크레딧 행이 없다고 늘리거나 줄이지 않는다.

## 바꾸지 않는 것

- CLI JSON, cache schema, app-server 해석
- 없는 5시간 값이나 주간 값을 0이나 이전 값으로 합성하는 것
- Grok Extra Usage Credits를 이 항목처럼 보여주는 것
- 메뉴바 앱이 auth store를 읽는 것

## 스크린샷

README 팝오버 스크린샷은 팝오버 바깥에 여백을 둔다. 둥근 테두리가 그림의
상하좌우에 닿아 잘리면 안 된다. 이 렌더는 회귀용이며, 설치본 팝오버를 손으로
연 검수는 아니다.

## 검증

```sh
git diff --check
./script/verify_v193_codex_remaining_credits_contract.sh --self-test
./script/verify_v193_release_readiness.sh --self-test
./script/verify_readme_screenshots.sh
```
