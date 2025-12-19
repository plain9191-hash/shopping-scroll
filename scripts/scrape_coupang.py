#!/usr/bin/env python3
"""
쿠팡 베스트100 스크래퍼 (Selenium)
100개 상품을 스크롤해서 모두 가져옵니다.
"""

import json
import os
import re
import sys
import time
from datetime import datetime
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from webdriver_manager.chrome import ChromeDriverManager

# 카테고리 매핑
CATEGORIES = {
    'all': '',
    'fashion': '564553',
    'beauty': '176422',
    'baby': '221834',
    'food': '194176',
    'kitchen': '185569',
    'living': '115573',
    'interior': '184455',
    'digital': '178155',
    'sports': '317678',
    'car': '183960',
    'books': '317677',
    'toys': '317679',
    'office': '177195',
    'pet': '115574',
    'health': '305698',
}

DATA_DIR = '/Users/grace/price_tracker/data'


def setup_driver():
    """Chrome 드라이버 설정 (봇 감지 우회 포함)"""
    options = Options()
    options.add_argument('--headless=new')  # 새로운 headless 모드
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-blink-features=AutomationControlled')
    options.add_experimental_option('excludeSwitches', ['enable-automation'])
    options.add_experimental_option('useAutomationExtension', False)
    options.add_argument('--window-size=1920,1080')
    options.add_argument('--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')

    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=options)

    # webdriver 감지 우회
    driver.execute_cdp_cmd('Page.addScriptToEvaluateOnNewDocument', {
        'source': '''
            Object.defineProperty(navigator, 'webdriver', {
                get: () => undefined
            })
        '''
    })

    return driver


def scroll_and_load_all(driver, target_count=100):
    """스크롤하여 모든 상품 로드 (100개 목표)"""
    body = driver.find_element(By.TAG_NAME, 'body')
    last_count = 0
    no_change_count = 0

    for i in range(50):  # 최대 50번 시도
        products = driver.find_elements(By.CSS_SELECTOR, 'li.search-product')
        current_count = len(products)

        if current_count != last_count:
            print(f"  스크롤 {i+1}: {current_count}개 로드됨")
            last_count = current_count
            no_change_count = 0
        else:
            no_change_count += 1

        if current_count >= target_count:
            print(f"  ✅ {target_count}개 이상 로드 완료!")
            break

        # 여러 방식으로 스크롤 시도
        if i % 3 == 0:
            body.send_keys(Keys.END)
        elif i % 3 == 1:
            driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
        else:
            if products:
                driver.execute_script(
                    "arguments[0].scrollIntoView({behavior: 'smooth', block: 'end'});",
                    products[-1]
                )

        time.sleep(2)

        # 변화가 5번 연속 없으면 중단
        if no_change_count >= 5:
            print(f"  더 이상 로드되지 않음 (총 {current_count}개)")
            break

    return driver.find_elements(By.CSS_SELECTOR, 'li.search-product')


def scrape_category(driver, category_key, category_id):
    """카테고리별 상품 스크래핑"""
    base_url = 'https://www.coupang.com/np/best100/bestseller'
    url = f'{base_url}/{category_id}' if category_id else base_url

    print(f"\n{'='*50}")
    print(f"카테고리: {category_key} ({category_id or '전체'})")
    print(f"URL: {url}")
    print('='*50)

    driver.get(url)
    time.sleep(5)  # 초기 로딩 대기

    # 스크롤해서 모든 상품 로드
    product_elements = scroll_and_load_all(driver)
    print(f"찾은 상품 수: {len(product_elements)}")

    products = []
    for idx, elem in enumerate(product_elements[:100]):  # 최대 100개
        try:
            # 상품 ID
            product_id = elem.get_attribute('data-product-id') or elem.get_attribute('id') or ''

            # 상품명
            title = ''
            for selector in ['div.name', '.name', 'dt.name']:
                try:
                    title_elem = elem.find_element(By.CSS_SELECTOR, selector)
                    title = title_elem.text.strip()
                    if title:
                        break
                except:
                    continue

            # 가격
            current_price = 0
            for selector in ['strong.price-value', '.price-value', 'em.sale']:
                try:
                    price_elem = elem.find_element(By.CSS_SELECTOR, selector)
                    price_text = ''.join(filter(str.isdigit, price_elem.text))
                    if price_text:
                        current_price = int(price_text)
                        break
                except:
                    continue

            # 원가
            original_price = None
            for selector in ['del.base-price', '.base-price', 'del']:
                try:
                    original_elem = elem.find_element(By.CSS_SELECTOR, selector)
                    original_text = ''.join(filter(str.isdigit, original_elem.text))
                    if original_text:
                        original_price = int(original_text)
                        break
                except:
                    continue

            # 이미지
            image_url = ''
            try:
                img_elem = elem.find_element(By.CSS_SELECTOR, 'img')
                image_url = img_elem.get_attribute('src') or img_elem.get_attribute('data-img-src') or ''
                if image_url.startswith('//'):
                    image_url = 'https:' + image_url
            except:
                pass

            # 상품 링크
            product_url = ''
            try:
                link_elem = elem.find_element(By.CSS_SELECTOR, 'a.search-product-link')
                product_url = link_elem.get_attribute('href') or ''
                if product_url.startswith('/'):
                    product_url = 'https://www.coupang.com' + product_url
            except:
                pass

            # 리뷰 수
            review_count = 0
            try:
                review_elem = elem.find_element(By.CSS_SELECTOR, 'span.rating-total-count')
                review_text = ''.join(filter(str.isdigit, review_elem.text))
                if review_text:
                    review_count = int(review_text)
            except:
                pass

            # 별점
            average_rating = 0.0
            try:
                rating_elem = elem.find_element(By.CSS_SELECTOR, 'em.rating')
                rating_style = rating_elem.get_attribute('style') or ''
                if 'width' in rating_style:
                    match = re.search(r'width:\s*([\d.]+)%', rating_style)
                    if match:
                        width_percent = float(match.group(1))
                        average_rating = round(width_percent / 20, 1)
            except:
                pass

            # 로켓배송 여부
            is_rocket = False
            try:
                elem.find_element(By.CSS_SELECTOR, '.badge.rocket, .badge-rocket, img[alt*="로켓"]')
                is_rocket = True
            except:
                if '로켓배송' in elem.text or '로켓직구' in elem.text:
                    is_rocket = True

            if title and current_price > 0:
                avg_price = original_price or int(current_price * 1.1)
                price_change = ((current_price - avg_price) / avg_price * 100) if avg_price > 0 else 0

                product = {
                    'id': f'coupang_{product_id}' if product_id else f'coupang_{idx}',
                    'title': title,
                    'imageUrl': image_url,
                    'currentPrice': current_price,
                    'originalPrice': original_price,
                    'averagePrice': avg_price,
                    'priceChangePercent': round(price_change, 2),
                    'source': 'coupang',
                    'category': category_key,
                    'isRocketDelivery': is_rocket,
                    'isLowestPrice': price_change < -20,
                    'productUrl': product_url,
                    'reviewCount': review_count,
                    'averageRating': average_rating,
                    'ranking': idx + 1,
                }
                products.append(product)

        except Exception as e:
            print(f"  상품 {idx+1} 파싱 오류: {e}")
            continue

    print(f"파싱 완료: {len(products)}개 상품")
    return products


def save_to_json(products, category_key):
    """JSON 파일로 저장"""
    os.makedirs(DATA_DIR, exist_ok=True)

    today = datetime.now().strftime('%Y-%m-%d')
    filename = f'{today}_{category_key}.json'
    filepath = os.path.join(DATA_DIR, filename)

    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(products, f, ensure_ascii=False, indent=2)

    print(f"저장 완료: {filepath} ({len(products)}개)")
    return filepath


def main():
    """메인 함수"""
    if len(sys.argv) > 1:
        categories_to_scrape = sys.argv[1:]
    else:
        categories_to_scrape = list(CATEGORIES.keys())

    print("="*60)
    print("쿠팡 베스트100 스크래퍼 (Selenium)")
    print(f"대상 카테고리: {len(categories_to_scrape)}개")
    print("="*60)

    driver = setup_driver()

    try:
        for category_key in categories_to_scrape:
            if category_key not in CATEGORIES:
                print(f"알 수 없는 카테고리: {category_key}")
                continue

            category_id = CATEGORIES[category_key]
            products = scrape_category(driver, category_key, category_id)

            if products:
                save_to_json(products, category_key)

            time.sleep(2)

    finally:
        driver.quit()

    print("\n" + "="*60)
    print("스크래핑 완료!")
    print("="*60)


if __name__ == '__main__':
    main()
