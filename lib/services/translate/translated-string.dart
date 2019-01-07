import 'package:little_light/services/translate/app-translations.service.dart';

class TranslatedString{
  Map<String, String> languages = new Map();
  TranslatedString({
    String en,
    String fr,
    String es,
    String de,
    String it,
    String ja,
    String ptBR,
    String esMX,
    String ru,
    String pl,
    String ko,
    String zhCht
  }){
    languages['de'] = de;
    languages['en'] = en;
    languages['es'] = es;
    languages['es-mx'] = esMX;
    languages['fr'] = fr;
    languages['it'] = it;
    languages['ja'] = ja;
    languages['pl'] = pl;
    languages['pt-br'] = ptBR;
    languages['ru'] = ru;
    languages['ko'] = ko;
    languages['zh-cht'] = zhCht;
  }
  String get([String lang, Map<String, String> params]){
    if(lang != null && languages.containsKey(lang)){
      return languages[lang];
    }
    if(languages[AppTranslations.currentLanguage] != null ){
      return languages[AppTranslations.currentLanguage];
    }
    return languages[AppTranslations.defaultLanguage];
  }

  @override
    String toString() {
      return this.get();
    }
}