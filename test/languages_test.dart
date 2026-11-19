import 'package:flutter_test/flutter_test.dart';
import 'package:iju/app/languages.dart';
import 'package:iju/app/session.dart';

void main() {
  test('처음 켰을 때 모국어는 영어예요', () {
    expect(AppSession.language, 'en');
    expect(nt('Nghe'), 'Listen');
  });

  tearDown(() => AppSession.language = 'vi');

  test('보조 문구는 고른 모국어로 바뀌어요', () {
    AppSession.language = 'vi';
    expect(nt('Nghe'), 'Nghe');
    AppSession.language = 'th';
    expect(nt('Nghe'), 'ฟัง');
    AppSession.language = 'zh';
    expect(nt('Đã chọn {n} món', {'n': 2}), '已选 2 道菜');
  });

  test('번역이 없는 문구는 영어, 영어도 없으면 원문', () {
    AppSession.language = 'ko';
    expect(nt('Nghe'), 'Listen');
    expect(nt('없는 문구'), '없는 문구');
  });

  test('아이디어 소개서의 언어(베트남·필리핀·캄보디아)와 종교권 언어가 모두 있어요', () {
    final codes = {for (final l in appLanguages) l.code};
    expect(
      codes,
      containsAll([
        'vi',
        'fil',
        'km',
        'lo',
        'th',
        'id',
        'uz',
        'mn',
        'ne',
        'zh',
      ]),
    );
  });
}
