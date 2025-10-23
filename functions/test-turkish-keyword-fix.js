/**
 * Test Turkish Keyword Extraction - Debugging "Şafak fenomeni" issue
 */

const { ai } = require('./lib/genkit-instance');
const { getRouterModel } = require('./lib/providers');

async function testKeywordExtraction() {
  console.log('🔍 Testing Turkish → English Keyword Extraction\n');

  const testQuestions = [
    'Şafak fenomeni nedir?',
    'Dawn fenomeni nedir?',
    'SGLT2 inhibitörleri nedir?',
    'Metformin nasıl kullanılır?',
    'Aralıklı oruç diyabette etkili mi?'
  ];

  for (const question of testQuestions) {
    console.log(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
    console.log(`Turkish: "${question}"`);
    console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);

    const prompt = `Sen bir tıbbi araştırma kütüphanecisisin ve PubMed veritabanı aramalarında uzmansın.
Bu Türkçe diyabet sorusundan PubMed için en etkili İNGİLİZCE arama kelimelerini çıkar.

ÖNEMLİ: PubMed sadece İngilizce çalışır, bu yüzden Türkçe terimleri İngilizce tıbbi terimlerine çevir.

Türkçe Soru: "${question}"

Çıkar:
1. Tıbbi terimler (mümkünse MeSH terminolojisi kullan)
2. İlaç isimleri (jenerik ve marka adları)
3. Hastalıklar ve komplikasyonlar
4. Eğer belirtilmişse çalışma tipleri (RCT, meta-analiz, vb.)

SADECE PubMed arama sorgusunu İNGİLİZCE olarak tek satırda ver.
Boolean operatörler (AND, OR) ve MeSH terimlerini kullan.

Örnekler:
Türkçe: "SGLT2 inhibitörlerinin kardiyovasküler riski azaltması hakkında son çalışmalar ne diyor?"
İngilizce Sorgu: (SGLT2 inhibitors OR sodium-glucose cotransporter-2 inhibitors) AND cardiovascular risk AND diabetes

Türkçe: "Aralıklı oruç Tip 2 diyabette etkili mi, klinik kanıtlar nedir?"
İngilizce Sorgu: intermittent fasting AND type 2 diabetes AND clinical trial

Türkçe: "Metformin hamilelikte güvenli mi, gestasyonel diyabet için?"
İngilizce Sorgu: metformin AND pregnancy AND gestational diabetes AND safety

Sıra sende - SADECE İngilizce arama sorgusunu ver:`;

    try {
      const result = await ai.generate({
        model: getRouterModel(),
        config: {
          temperature: 0.1,
          maxOutputTokens: 100
        },
        prompt: prompt
      });

      const keywords = result.text.trim();
      console.log(`✅ English Keywords: "${keywords}"`);

    } catch (error) {
      console.error(`❌ Error:`, error.message);
    }
  }
}

testKeywordExtraction()
  .then(() => {
    console.log('\n✅ Test completed');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Test failed:', error);
    process.exit(1);
  });
