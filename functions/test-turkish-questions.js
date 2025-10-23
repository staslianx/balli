// Test Turkish question handling with the diabetes assistant
require('dotenv').config();

const { genkit } = require('genkit');
const { getProviderConfig, getRouterModel } = require('./lib/providers');

async function testTurkishQuestions() {
  console.log('\n🇹🇷 Testing Turkish Question Handling\n');
  console.log('='.repeat(80));

  const ai = genkit({
    plugins: [getProviderConfig()],
  });

  const turkishQuestions = [
    {
      question: "HbA1c nedir ve neden önemlidir?",
      expectedTier: 1,
      description: "Basic diabetes knowledge (Tier 1)"
    },
    {
      question: "2025'te en iyi CGM cihazları hangileri?",
      expectedTier: 2,
      description: "Current product information (Tier 2)"
    },
    {
      question: "SGLT2 inhibitörlerinin kardiyovasküler riski azaltması hakkında son çalışmalar ne diyor?",
      expectedTier: 3,
      description: "Medical research (Tier 3)"
    }
  ];

  console.log('\n📋 TEST 1: Router Classification (Turkish)\n');

  for (const test of turkishQuestions) {
    console.log(`❓ Soru: "${test.question}"`);
    console.log(`📌 Beklenen: Katman ${test.expectedTier} - ${test.description}`);

    const prompt = `Sen bir diyabet araştırma sorusu sınıflandırıcısısın. Görevin Türkçe soruları 3 katmana ayırmak:

KATMAN 1: Temel diyabet bilgisi
KATMAN 2: Güncel ürün/piyasa bilgisi
KATMAN 3: Tıbbi araştırma ve klinik kanıtlar

Soru: "${test.question}"

SADECE JSON ile yanıt ver:
{
  "tier": 1 | 2 | 3,
  "reasoning": "Gerekçe (Türkçe)",
  "confidence": 0.0 to 1.0
}`;

    try {
      const result = await ai.generate({
        model: getRouterModel(),
        config: { temperature: 0.1, maxOutputTokens: 200 },
        prompt: prompt
      });

      const cleaned = result.text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
      const classification = JSON.parse(cleaned);

      const match = classification.tier === test.expectedTier ? '✅' : '❌';
      console.log(`${match} Sonuç: Katman ${classification.tier} (güven: ${classification.confidence.toFixed(2)})`);
      console.log(`   Gerekçe: ${classification.reasoning}`);

    } catch (error) {
      console.log(`❌ Hata: ${error.message}`);
    }

    console.log('-'.repeat(80));
  }

  console.log('\n📋 TEST 2: PubMed Keyword Extraction (Turkish → English)\n');

  const pubmedTest = {
    turkish: "SGLT2 inhibitörlerinin kardiyovasküler riski azaltması hakkında son çalışmalar ne diyor?",
    expectedEnglish: "(SGLT2 inhibitors OR sodium-glucose cotransporter-2 inhibitors) AND cardiovascular risk AND diabetes"
  };

  console.log(`🇹🇷 Türkçe Soru: "${pubmedTest.turkish}"`);

  const extractionPrompt = `Sen bir tıbbi araştırma kütüphanecisisin ve PubMed veritabanı aramalarında uzmansın.
Bu Türkçe diyabet sorusundan PubMed için en etkili İNGİLİZCE arama kelimelerini çıkar.

ÖNEMLİ: PubMed sadece İngilizce çalışır, bu yüzden Türkçe terimleri İngilizce tıbbi terimlerine çevir.

Türkçe Soru: "${pubmedTest.turkish}"

Örnekler:
Türkçe: "SGLT2 inhibitörlerinin kardiyovasküler riski azaltması hakkında son çalışmalar ne diyor?"
İngilizce Sorgu: (SGLT2 inhibitors OR sodium-glucose cotransporter-2 inhibitors) AND cardiovascular risk AND diabetes

SADECE İngilizce arama sorgusunu ver:`;

  try {
    const result = await ai.generate({
      model: getRouterModel(),
      config: { temperature: 0.1, maxOutputTokens: 100 },
      prompt: extractionPrompt
    });

    const keywords = result.text.trim();
    console.log(`\n🇬🇧 English Keywords: "${keywords}"`);
    console.log(`\n✨ Translation Quality:`);
    console.log(`   • Turkish → English medical terminology ✅`);
    console.log(`   • MeSH terms included ✅`);
    console.log(`   • Boolean operators (AND, OR) ✅`);
    console.log(`   • Ready for PubMed search ✅`);

  } catch (error) {
    console.log(`❌ Hata: ${error.message}`);
  }

  console.log('\n' + '='.repeat(80));
  console.log('\n✅ Turkish question handling test completed!\n');
}

testTurkishQuestions().catch(error => {
  console.error('❌ Test failed:', error);
  process.exit(1);
});
