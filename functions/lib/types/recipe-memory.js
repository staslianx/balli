"use strict";
/**
 * Recipe Memory System Types
 * Types for memory-aware recipe generation with diversity tracking
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.SUBCATEGORY_CONTEXTS = exports.MEMORY_LIMITS = exports.RecipeSubcategory = void 0;
/**
 * The 9 independent meal subcategories for recipe memory tracking
 */
var RecipeSubcategory;
(function (RecipeSubcategory) {
    RecipeSubcategory["KAHVALTI"] = "Kahvalt\u0131";
    RecipeSubcategory["DOYURUCU_SALATA"] = "Doyurucu salata";
    RecipeSubcategory["HAFIF_SALATA"] = "Hafif salata";
    RecipeSubcategory["KARBONHIDRAT_PROTEIN"] = "Karbonhidrat ve Protein Uyumu";
    RecipeSubcategory["TAM_TAHIL_MAKARNA"] = "Tam tah\u0131l makarna \u00E7e\u015Fitleri";
    RecipeSubcategory["SANA_OZEL_TATLILAR"] = "Sana \u00F6zel tatl\u0131lar";
    RecipeSubcategory["DONDURMA"] = "Dondurma";
    RecipeSubcategory["MEYVE_SALATASI"] = "Meyve salatas\u0131";
    RecipeSubcategory["ATISTIRMALIKLAR"] = "At\u0131\u015Ft\u0131rmal\u0131klar";
})(RecipeSubcategory || (exports.RecipeSubcategory = RecipeSubcategory = {}));
/**
 * Memory limits per subcategory based on realistic variety potential
 */
exports.MEMORY_LIMITS = {
    [RecipeSubcategory.KAHVALTI]: 25,
    [RecipeSubcategory.DOYURUCU_SALATA]: 30,
    [RecipeSubcategory.HAFIF_SALATA]: 20,
    [RecipeSubcategory.KARBONHIDRAT_PROTEIN]: 30,
    [RecipeSubcategory.TAM_TAHIL_MAKARNA]: 25,
    [RecipeSubcategory.SANA_OZEL_TATLILAR]: 15,
    [RecipeSubcategory.DONDURMA]: 10,
    [RecipeSubcategory.MEYVE_SALATASI]: 10,
    [RecipeSubcategory.ATISTIRMALIKLAR]: 20
};
/**
 * Context descriptions for recipe generation prompts
 */
exports.SUBCATEGORY_CONTEXTS = {
    [RecipeSubcategory.KAHVALTI]: "Diyabet dostu kahvaltı",
    [RecipeSubcategory.DOYURUCU_SALATA]: "Protein içeren ana yemek olarak servis edilen doyurucu bir salata",
    [RecipeSubcategory.HAFIF_SALATA]: "Yan yemek olarak servis edilen hafif bir salata",
    [RecipeSubcategory.KARBONHIDRAT_PROTEIN]: "Dengeli karbonhidrat ve protein kombinasyonu içeren akşam yemeği",
    [RecipeSubcategory.TAM_TAHIL_MAKARNA]: "Tam tahıllı makarna çeşitleri",
    [RecipeSubcategory.SANA_OZEL_TATLILAR]: "Diyabet dostu tatlı versiyonları",
    [RecipeSubcategory.DONDURMA]: "Ninja Creami makinesi için diyabet dostu dondurma",
    [RecipeSubcategory.MEYVE_SALATASI]: "Diyabet yönetimine uygun meyve salatası",
    [RecipeSubcategory.ATISTIRMALIKLAR]: "Sağlıklı atıştırmalıklar"
};
//# sourceMappingURL=recipe-memory.js.map