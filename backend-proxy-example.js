/**
 * 백엔드 프록시 서버 예시 (Node.js + Express)
 * 
 * 이 서버를 사용하면 웹에서 CORS 문제 없이 스크래핑이 가능합니다.
 * 
 * 설치 방법:
 * 1. npm init -y
 * 2. npm install express cors axios cheerio
 * 3. node backend-proxy-example.js
 * 
 * 실행:
 * node backend-proxy-example.js
 * 
 * Flutter 앱에서 사용:
 * http.get(Uri.parse('http://localhost:3000/api/coupang'))
 */

const express = require('express');
const cors = require('cors');
const axios = require('axios');
const cheerio = require('cheerio');

const app = express();
const PORT = 3000;

// CORS 설정 - Flutter 웹 앱의 도메인을 허용
app.use(cors({
  origin: '*', // 프로덕션에서는 특정 도메인으로 제한하세요
  credentials: true
}));

app.use(express.json());

// 쿠팡 상품 데이터 가져오기
app.get('/api/coupang', async (req, res) => {
  try {
    const { page = 0, limit = 10 } = req.query;
    
    const urls = [
      'https://www.coupang.com/np/bestSeller',
      'https://www.coupang.com/np/categories/186764',
      'https://www.coupang.com/np/categories/186765',
    ];
    const url = urls[page % urls.length];

    console.log(`[쿠팡] 요청: ${url}`);

    const response = await axios.get(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.9',
        'Referer': 'https://www.coupang.com/',
      },
      timeout: 30000,
    });

    const $ = cheerio.load(response.data);
    const products = [];

    // 쿠팡 상품 파싱 (실제 HTML 구조에 맞게 수정 필요)
    $('li.baby-product, li.search-product').each((index, element) => {
      if (products.length >= limit) return false;

      const $el = $(element);
      const title = $el.find('.name, .product-name').text().trim();
      const imageUrl = $el.find('img').attr('src') || $el.find('img').attr('data-img-src') || '';
      const priceText = $el.find('.price-value, .price').text().trim();
      const productUrl = $el.find('a').attr('href') || '';

      if (title && imageUrl && priceText) {
        const price = parseInt(priceText.replace(/[^\d]/g, '')) || 0;
        
        products.push({
          id: `coupang_${index}_${Date.now()}`,
          title: title,
          imageUrl: imageUrl.startsWith('http') ? imageUrl : `https:${imageUrl}`,
          currentPrice: price,
          averagePrice: Math.round(price * 1.1),
          priceChangePercent: -10,
          source: 'coupang',
          productUrl: productUrl.startsWith('http') ? productUrl : `https://www.coupang.com${productUrl}`,
        });
      }
    });

    console.log(`[쿠팡] ${products.length}개 상품 반환`);
    res.json(products);
  } catch (error) {
    console.error('[쿠팡] 오류:', error.message);
    res.status(500).json({ error: error.message });
  }
});

// 네이버 쇼핑 상품 데이터 가져오기
app.get('/api/naver', async (req, res) => {
  try {
    const { keyword = '노트북', page = 0, limit = 10 } = req.query;
    
    const searchUrl = `https://search.shopping.naver.com/search/all?query=${encodeURIComponent(keyword)}&pagingIndex=${parseInt(page) + 1}&pagingSize=${limit}`;

    console.log(`[네이버] 요청: ${searchUrl}`);

    const response = await axios.get(searchUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.9',
        'Referer': 'https://shopping.naver.com/',
      },
      timeout: 30000,
    });

    const $ = cheerio.load(response.data);
    const products = [];

    // 네이버 쇼핑 상품 파싱 (실제 HTML 구조에 맞게 수정 필요)
    $('.product_item, .productList_item, .basicList_item').each((index, element) => {
      if (products.length >= limit) return false;

      const $el = $(element);
      const title = $el.find('.product_title, .basicList_title, a[class*="title"]').text().trim();
      const imageUrl = $el.find('img').attr('src') || $el.find('img').attr('data-src') || '';
      const priceText = $el.find('.price, .price_num').text().trim();
      const productUrl = $el.find('a').attr('href') || '';

      if (title && imageUrl && priceText) {
        const price = parseInt(priceText.replace(/[^\d]/g, '')) || 0;
        
        products.push({
          id: `naver_${index}_${Date.now()}`,
          title: title,
          imageUrl: imageUrl.startsWith('http') ? imageUrl : `https:${imageUrl}`,
          currentPrice: price,
          averagePrice: Math.round(price * 1.1),
          priceChangePercent: -10,
          source: 'naver',
          productUrl: productUrl.startsWith('http') ? productUrl : `https://shopping.naver.com${productUrl}`,
        });
      }
    });

    console.log(`[네이버] ${products.length}개 상품 반환`);
    res.json(products);
  } catch (error) {
    console.error('[네이버] 오류:', error.message);
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`🚀 백엔드 프록시 서버가 http://localhost:${PORT} 에서 실행 중입니다.`);
  console.log(`📡 API 엔드포인트:`);
  console.log(`   - GET http://localhost:${PORT}/api/coupang?page=0&limit=10`);
  console.log(`   - GET http://localhost:${PORT}/api/naver?keyword=노트북&page=0&limit=10`);
});


