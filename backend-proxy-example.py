"""
백엔드 프록시 서버 예시 (Python + Flask)

이 서버를 사용하면 웹에서 CORS 문제 없이 스크래핑이 가능합니다.

설치 방법:
1. pip install flask flask-cors requests beautifulsoup4
2. python backend-proxy-example.py

실행:
python backend-proxy-example.py

Flutter 앱에서 사용:
http.get(Uri.parse('http://localhost:5000/api/coupang'))
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
import requests
from bs4 import BeautifulSoup

app = Flask(__name__)
CORS(app)  # 모든 도메인에서 접근 허용 (프로덕션에서는 특정 도메인으로 제한)

@app.route('/api/coupang', methods=['GET'])
def get_coupang_products():
    try:
        page = int(request.args.get('page', 0))
        limit = int(request.args.get('limit', 10))
        
        urls = [
            'https://www.coupang.com/np/bestSeller',
            'https://www.coupang.com/np/categories/186764',
            'https://www.coupang.com/np/categories/186765',
        ]
        url = urls[page % len(urls)]

        print(f'[쿠팡] 요청: {url}')

        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'ko-KR,ko;q=0.9',
            'Referer': 'https://www.coupang.com/',
        }

        response = requests.get(url, headers=headers, timeout=30)
        response.raise_for_status()

        soup = BeautifulSoup(response.text, 'html.parser')
        products = []

        # 쿠팡 상품 파싱 (실제 HTML 구조에 맞게 수정 필요)
        product_elements = soup.select('li.baby-product, li.search-product')[:limit]
        
        for index, element in enumerate(product_elements):
            title_elem = element.select_one('.name, .product-name')
            img_elem = element.select_one('img')
            price_elem = element.select_one('.price-value, .price')
            link_elem = element.select_one('a')

            if title_elem and img_elem and price_elem:
                title = title_elem.get_text(strip=True)
                image_url = img_elem.get('src') or img_elem.get('data-img-src') or ''
                price_text = price_elem.get_text(strip=True)
                product_url = link_elem.get('href', '') if link_elem else ''

                if title and image_url and price_text:
                    price = int(''.join(filter(str.isdigit, price_text))) or 0
                    
                    if not image_url.startswith('http'):
                        image_url = f'https:{image_url}'
                    if product_url and not product_url.startswith('http'):
                        product_url = f'https://www.coupang.com{product_url}'

                    products.append({
                        'id': f'coupang_{index}_{int(__import__("time").time() * 1000)}',
                        'title': title,
                        'imageUrl': image_url,
                        'currentPrice': price,
                        'averagePrice': int(price * 1.1),
                        'priceChangePercent': -10,
                        'source': 'coupang',
                        'productUrl': product_url,
                    })

        print(f'[쿠팡] {len(products)}개 상품 반환')
        return jsonify(products)
    except Exception as e:
        print(f'[쿠팡] 오류: {str(e)}')
        return jsonify({'error': str(e)}), 500

@app.route('/api/naver', methods=['GET'])
def get_naver_products():
    try:
        keyword = request.args.get('keyword', '노트북')
        page = int(request.args.get('page', 0))
        limit = int(request.args.get('limit', 10))
        
        search_url = f'https://search.shopping.naver.com/search/all?query={keyword}&pagingIndex={page + 1}&pagingSize={limit}'

        print(f'[네이버] 요청: {search_url}')

        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'ko-KR,ko;q=0.9',
            'Referer': 'https://shopping.naver.com/',
        }

        response = requests.get(search_url, headers=headers, timeout=30)
        response.raise_for_status()

        soup = BeautifulSoup(response.text, 'html.parser')
        products = []

        # 네이버 쇼핑 상품 파싱 (실제 HTML 구조에 맞게 수정 필요)
        product_elements = soup.select('.product_item, .productList_item, .basicList_item')[:limit]
        
        for index, element in enumerate(product_elements):
            title_elem = element.select_one('.product_title, .basicList_title, a[class*="title"]')
            img_elem = element.select_one('img')
            price_elem = element.select_one('.price, .price_num')
            link_elem = element.select_one('a')

            if title_elem and img_elem and price_elem:
                title = title_elem.get_text(strip=True)
                image_url = img_elem.get('src') or img_elem.get('data-src') or ''
                price_text = price_elem.get_text(strip=True)
                product_url = link_elem.get('href', '') if link_elem else ''

                if title and image_url and price_text:
                    price = int(''.join(filter(str.isdigit, price_text))) or 0
                    
                    if not image_url.startswith('http'):
                        image_url = f'https:{image_url}'
                    if product_url and not product_url.startswith('http'):
                        product_url = f'https://shopping.naver.com{product_url}'

                    products.append({
                        'id': f'naver_{index}_{int(__import__("time").time() * 1000)}',
                        'title': title,
                        'imageUrl': image_url,
                        'currentPrice': price,
                        'averagePrice': int(price * 1.1),
                        'priceChangePercent': -10,
                        'source': 'naver',
                        'productUrl': product_url,
                    })

        print(f'[네이버] {len(products)}개 상품 반환')
        return jsonify(products)
    except Exception as e:
        print(f'[네이버] 오류: {str(e)}')
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print('🚀 백엔드 프록시 서버가 http://localhost:5000 에서 실행 중입니다.')
    print('📡 API 엔드포인트:')
    print('   - GET http://localhost:5000/api/coupang?page=0&limit=10')
    print('   - GET http://localhost:5000/api/naver?keyword=노트북&page=0&limit=10')
    app.run(port=5000, debug=True)


