# 가격 변동 추적 앱

쿠팡과 네이버 쇼핑의 상품 가격 변동을 실시간으로 추적하는 Flutter 앱입니다.

## 기능

- 🛒 쿠팡 메인페이지 상품 10개 표시
- 🛍️ 네이버 쇼핑 메인페이지 상품 10개 표시
- 📊 가격 변동률 실시간 표시
- 🔄 무한 스크롤로 추가 상품 로드
- 📱 웹 및 모바일 앱 지원

## 기술 스택

- Flutter 3.32.2
- Dart 3.8.1
- http: API 호출
- cached_network_image: 이미지 캐싱
- flutter_staggered_grid_view: 그리드 레이아웃
- html: HTML 파싱 (웹 스크래핑용)

## 실행 방법

### 웹에서 실행 (CORS 및 403/404 오류 해결)

**⚠️ 중요**: 웹 환경에서 직접 스크래핑은 브라우저의 CORS 정책으로 인해 **근본적으로 제한적**입니다. 쿠팡/네이버 쇼핑 서버는 봇 요청을 차단하며, 브라우저 보안 정책도 이를 막습니다.

#### 개발 환경에서 테스트하기

개발 환경에서만 작동하는 임시 해결책:

```bash
flutter run -d chrome --web-browser-flag="--disable-web-security" --web-browser-flag="--user-data-dir=/tmp/chrome_dev_session"
```

또는 간단하게:

```bash
flutter run -d chrome --web-browser-flag="--disable-web-security"
```

**주의**: 이 방법은 **개발 환경에서만** 작동하며, 프로덕션에서는 작동하지 않습니다.

#### 프로덕션 환경 해결 방법

웹 앱을 배포할 때는 다음 중 하나를 선택해야 합니다:

1. **백엔드 프록시 서버 구축 (권장)**

   - Node.js, Python, PHP 등으로 백엔드 서버 구축
   - 서버에서 스크래핑 후 API로 제공
   - 가장 안정적이고 프로덕션에 적합

2. **네이버 쇼핑 API 사용 (권장)**

   - 네이버 쇼핑 검색 API 키 설정
   - API를 통해 데이터 가져오기
   - CORS 문제 없이 작동

3. **모바일/데스크톱 앱으로 배포**
   - 웹이 아닌 Android/iOS/Desktop 앱으로 배포
   - CORS 문제가 없음

#### 오류별 해결 방법

- **CORS 오류**: 백엔드 프록시 서버 구축 또는 모바일 앱 사용
- **403 Forbidden**: 서버가 봇 요청을 차단. 백엔드 프록시 필요
- **404 Not Found**: URL이 변경되었거나 접근 불가. URL 확인 필요

### 일반 실행 (모바일/데스크톱)

```bash
flutter run
```

### 앱으로 빌드

#### Android

```bash
flutter build apk
```

#### iOS

```bash
flutter build ios
```

#### 웹 배포

```bash
flutter build web
```

## 프로젝트 구조

```
lib/
├── main.dart                 # 앱 진입점
├── models/
│   └── product.dart         # 상품 모델
├── services/
│   └── product_service.dart # 상품 데이터 서비스
├── screens/
│   └── home_screen.dart     # 메인 화면
└── widgets/
    └── product_card.dart    # 상품 카드 위젯
```

## 설정 방법

### 네이버 쇼핑 API 키 설정

네이버 쇼핑 검색 API를 사용하려면 네이버 개발자 센터에서 API 키를 발급받아야 합니다.

1. [네이버 개발자 센터](https://developers.naver.com)에 접속하여 로그인
2. **Application > 애플리케이션 등록** 메뉴에서 애플리케이션 등록
3. **사용 API**에서 **검색** 선택
4. 발급받은 **Client ID**와 **Client Secret** 확인
5. `lib/services/product_service.dart` 파일에서 다음 부분을 수정:

```dart
static const String _naverClientId = 'YOUR_NAVER_CLIENT_ID';
static const String _naverClientSecret = 'YOUR_NAVER_CLIENT_SECRET';
```

**보안 주의사항**: API 키는 절대 공개 저장소에 커밋하지 마세요. 환경 변수나 설정 파일을 사용하는 것을 권장합니다.

### 쿠팡 상품 데이터

쿠팡은 공식 상품 검색 API를 제공하지 않습니다. 현재는 웹 스크래핑을 시도하지만, **웹 환경에서 CORS 정책과 서버의 봇 차단으로 인해 직접 스크래핑이 실패할 수 있습니다**.

**해결 방법**:

1. **개발 환경**: Chrome 실행 시 `--disable-web-security` 플래그 사용 (위의 실행 방법 참조)
2. **프로덕션**: **백엔드 서버를 구축하여 서버에서 스크래핑하고 API로 제공** (필수)
3. **모바일/데스크톱 앱**: 웹이 아닌 앱으로 배포하면 CORS 문제 없음

**백엔드 프록시 서버 예시 (Node.js)**:

```javascript
const express = require("express");
const cors = require("cors");
const axios = require("axios");
const app = express();

app.use(cors());

app.get("/api/coupang", async (req, res) => {
  try {
    const response = await axios.get("https://www.coupang.com/np/bestSeller", {
      headers: {
        "User-Agent": "Mozilla/5.0...",
      },
    });
    res.send(response.data);
  } catch (error) {
    res.status(500).send("Error");
  }
});

app.listen(3000);
```

그리고 Flutter 앱에서는:

```dart
final response = await http.get(Uri.parse('http://your-backend.com/api/coupang'));
```

## 주의사항

- **네이버 API**: 네이버 쇼핑 검색 API는 하루 25,000회 호출 제한이 있습니다. API 키 설정을 권장합니다.
- **쿠팡**: 공식 API가 없어 웹 스크래핑을 시도하지만, **웹 환경에서는 CORS 정책으로 인해 실패할 수 있습니다**.
- **CORS**: 웹 환경에서 직접 스크래핑할 경우 CORS 오류가 발생합니다. **프로덕션에서는 반드시 백엔드 프록시 서버를 사용해야 합니다**.
- **403/404 오류**: 서버가 봇 요청을 차단하거나 URL이 변경되었을 수 있습니다. 백엔드 프록시 서버 사용을 권장합니다.
- **서비스 약관**: 각 쇼핑몰의 이용약관을 확인하고 준수해야 합니다. 과도한 스크래핑은 IP 차단을 유발할 수 있습니다.

## 라이선스

이 프로젝트는 개인 사용 목적으로 만들어졌습니다.
