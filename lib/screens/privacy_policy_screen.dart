import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プライバシーポリシー'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('1. 収集する利用者情報および収集方法'),
            _bodyText('本アプリでは、以下の情報を収集・保持します。'),
            _bulletPoint('ユーザーが入力したキャンプギアに関する情報（名称、メーカー名、重量、数量、メモ、画像）'),
            _bulletPoint('ユーザーが作成した持ち出しセット（チェックリスト）の情報'),
            
            _sectionTitle('2. 利用目的'),
            _bodyText('収集した情報は、以下の目的でのみ利用します。'),
            _bulletPoint('アプリ内でのキャンプギアの管理および持ち出しリストの作成・表示'),
            _bulletPoint('ユーザー操作によるデータのバックアップおよびエクスポート'),

            _sectionTitle('3. 情報の保存および管理'),
            _bodyText('本アプリで入力されたすべてのデータは、ユーザーのデバイス内にのみ保存されます。開発者がユーザーのデータを閲覧、収集、または外部サーバーに保存することはありません。'),

            _sectionTitle('4. 第三者提供および外部送信'),
            _bodyText('本アプリは、以下の場合を除き、利用者情報を第三者に提供したり、外部へ送信したりすることはありません。'),
            _bulletPoint('ユーザーが「共有」機能や「バックアップ」機能を利用して、明示的に外部へデータを送信・保存する場合。'),
            _bulletPoint('法令に基づく提供要請があった場合。'),

            _sectionTitle('5. 外部サービスの使用について'),
            _bodyText('本アプリでは、以下の外部サービスを利用しています。'),
            _bulletPoint('Google Fonts: アプリ内のフォント表示に使用されます。'),
            _bulletPoint('Amazon.co.jp 検索: ユーザーの操作により、商品情報を検索するためにブラウザを開きます。'),

            _sectionTitle('6. 免責事項'),
            _bodyText('本アプリの利用により生じた何らかのトラブルや損失、損害等に対し、開発者は一切の責任を負わないものとします。'),

            _sectionTitle('7. プライバシーポリシーの変更'),
            _bodyText('本プライバシーポリシーは、アプリのアップデート等に伴い、予告なく変更されることがあります。'),

            _sectionTitle('8. お問い合わせ窓口'),
            _bodyText('ご不明な点やご要望がございましたら、以下のメールアドレスまでご連絡ください。'),
            _bodyText('Email: amethyst.black.pearl@gmail.com'),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _bodyText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, height: 1.5),
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16, height: 1.5)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
