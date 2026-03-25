import 'package:flutter/material.dart';
import 'dart:convert'; 
import 'package:flutter/services.dart'; 
import 'package:flutter/material.dart';

void main() => runApp(const LawLearnerApp());

// --- [데이터 모델] ---

class SubPoint {
  final String letter;
  final String text;
  SubPoint({required this.letter, required this.text});

  factory SubPoint.fromJson(Map<String, dynamic> json) => 
      SubPoint(letter: json['letter'] ?? "", text: json['text'] ?? "");
}

class SubItem {
  final String number;
  final String text;
  final List<SubPoint> subPoints;
  SubItem({required this.number, required this.text, this.subPoints = const []});

  // 수정된 SubItem factory
  factory SubItem.fromJson(Map<String, dynamic> json) => SubItem(
      // JSON에 letter가 없으면 number를 찾아보고, 둘 다 없으면 빈 문자열
      number: (json['letter'] ?? json['number'] ?? "").toString(), 
      text: json['text'] ?? "",
      subPoints: (json['subPoints'] as List? ?? [])
          .map((s) => SubPoint.fromJson(s))
          .toList(),
    );
}

class Paragraph {
  final String order;
  final String text;
  final List<SubItem> subItems;
  List<String> keywords;
  String userNote;
  bool isFavorite;
  int wrongCount;
  final String parentArticleId;
  final String parentTreaty;

  Paragraph({
    required this.order, required this.text, required this.subItems,
    required this.parentArticleId, required this.parentTreaty,
    List<String>? keywords, this.userNote = "", this.isFavorite = false, this.wrongCount = 0,
  }) : keywords = keywords ?? [];

  factory Paragraph.fromJson(Map<String, dynamic> json, String articleId, String treaty) {
    return Paragraph(
      order: json['order'] ?? "1",
      text: json['text'] ?? "",
      parentArticleId: articleId,
      parentTreaty: treaty,
      subItems: (json['subItems'] as List? ?? [])
          .map((s) => SubItem.fromJson(s))
          .toList(),
      keywords: List<String>.from(json['keywords'] ?? []),
      isFavorite: json['isFavorite'] ?? false,
      wrongCount: json['wrongCount'] ?? 0,
      userNote: json['userNote'] ?? "",
    );
  }
}

class Article {
  final String id;
  final String title;
  final String treaty;
  final List<Paragraph> paragraphs;
  Article({required this.id, required this.title, required this.treaty, required this.paragraphs});

  factory Article.fromJson(Map<String, dynamic> json) {
    String articleId = json['id'] ?? "";
    String treatyName = json['treaty'] ?? "VCLT";
    return Article(
      id: articleId,
      title: json['title'] ?? "",
      treaty: treatyName,
      paragraphs: (json['paragraphs'] as List? ?? [])
          .map((p) => Paragraph.fromJson(p, articleId, treatyName))
          .toList(),
    );
  }
}
int globalHighScore = 0;

class LawLearnerApp extends StatelessWidget {
  const LawLearnerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: const Color(0xFF1B5E20),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20), primary: const Color(0xFF1B5E20)),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1B5E20), foregroundColor: Colors.white, elevation: 0, centerTitle: true),
      ),
      home: const MainDashboard(),
    );
  }
}

// --- [1. 메인 대시보드] ---

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});
  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  String _archiveSearchQuery = "";
  List<Article> _allArticles = []; // 초기값 빈 리스트
  bool _isLoading = true; // 로딩 상태 추가

  @override
  void initState() {
    super.initState();
    _loadData(); // 데이터 로드 시작
  }

  Future<void> _loadData() async {
    try {
      // 1. JSON 파일 읽기
      final String response = await rootBundle.loadString('assets/data/treaty_vclt.json');
      final List<dynamic> data = json.decode(response);

      // 2. 모델로 변환
      setState(() {
        _allArticles = data.map((json) => Article.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("데이터 로딩 실패: $e");
      setState(() => _isLoading = false);
    }
  }

  List<Paragraph> get _favoriteParagraphs {
    List<Paragraph> favs = [];
    for (var art in _allArticles) {
      favs.addAll(art.paragraphs.where((p) => p.isFavorite));
    }
    return favs;
  }

  @override
Widget build(BuildContext context) {
  if (_isLoading) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
  final treaties = [
      {"name": "조약법에 관한 비엔나 협약", "code": "VCLT"},
      {"name": "국제연합헌장", "code": "UN Charter"},
    ].where((t) => t['name']!.contains(_archiveSearchQuery) || t['code']!.contains(_archiveSearchQuery.toUpperCase())).toList();



    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildSectionTitle("GAME ZONE", top: 30),
          _buildGameZone(),
          _buildSectionTitle("ARCHIVE ZONE", top: 20),
          _buildSearchField(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                if (_favoriteParagraphs.isNotEmpty && _archiveSearchQuery.isEmpty)
                  _specialCategoryCard("★ 즐겨찾기 보관함 ★", _favoriteParagraphs),
                ...treaties.map((t) => _treatyCard(t['name']!, t['code']!)).toList(),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.all(25),
    decoration: const BoxDecoration(color: Color(0xFF1B5E20), borderRadius: BorderRadius.vertical(bottom: Radius.circular(25))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text("LAW PRACTICE", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
      Text("BEST : $globalHighScore", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ]),
  );

  Widget _buildSectionTitle(String title, {double top = 15}) => Padding(
    padding: EdgeInsets.only(left: 24, top: top, bottom: 8),
    child: Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20), letterSpacing: 1.2))),
  );

  // 1. 게임존 빌드 (최대 4개씩 줄바꿈)
  Widget _buildGameZone() {
    double screenWidth = MediaQuery.of(context).size.width;
    // 패딩과 간격을 고려하여 버튼 너비 계산
    double buttonWidth = (screenWidth - 60) / 4; 

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.start,
        children: [
          _gameBtn("키워드 QUIZ", Icons.bolt, const Color(0xFF004D40), () => _startQuiz("NORMAL"), buttonWidth),
          _gameBtn("즐겨찾기 QUIZ", Icons.star, const Color(0xFF2E7D32), () => _startQuiz("IMPORTANT"), buttonWidth),
          _gameBtn("오답 ZONE", Icons.history_edu, const Color(0xFF66BB6A), () => _startQuiz("CHECK"), buttonWidth),
          _gameBtn("조문 암기 MODE", Icons.psychology, const Color(0xFF1B5E20), () => _startFullTextQuiz(), buttonWidth),
          _gameBtn("추후 업데이트", Icons.manage_search, const Color(0xFF00695C), () {
            // 여기에 원하는 이동 로직 추가 가능
          }, buttonWidth),
        ],
      ),
    );
  }

  // 2. 버튼 위젯 (이 함수는 하나만 존재해야 합니다!)
  Widget _gameBtn(String t, IconData i, Color c, VoidCallback onTap, double width) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: width, 
      height: 85, 
      decoration: BoxDecoration(
        color: c, 
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Icon(i, color: Colors.white, size: 20), 
          const SizedBox(height: 6), 
          Text(
            t, 
            textAlign: TextAlign.center, 
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
          )
        ]
      )
    ),
  );

  Widget _buildSearchField() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: TextField(
      decoration: InputDecoration(
        hintText: "국제법 검색...",
        hintStyle: const TextStyle(fontSize: 13), 
        prefixIcon: const Icon(Icons.search, size: 20), // 아이콘 크기도 살짝 줄임
        filled: true,
        fillColor: Colors.grey.shade100,
        // 아래 부분이 핵심입니다.
        isDense: true, // 텍스트 필드를 더 촘촘하게 만듦
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15), // 세로 여백을 10으로 축소
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15), 
          borderSide: BorderSide.none
        ),
      ),
      onChanged: (val) => setState(() => _archiveSearchQuery = val),
    ),
  );

  Widget _specialCategoryCard(String title, List<Paragraph> favs) => Card(
    color: const Color(0xFFE8F5E9), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Color(0xFFA5D6A7))),
    child: ListTile(
      leading: const Icon(Icons.stars, color: Color(0xFF1B5E20)), 
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), 
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FavoriteListScreen(favorites: favs, allArticles: _allArticles))).then((_) => setState(() {}))
    ),
  );

  Widget _treatyCard(String n, String c) {
  // 공백 제거 및 대문자 변환 후 비교
  final filtered = _allArticles.where((a) => 
    a.treaty.trim().toUpperCase() == c.trim().toUpperCase()
  ).toList();

  return Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
      side: BorderSide(color: Colors.grey.shade200),
    ),
    child: ListTile(
      title: Text(n, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text("$c | 조문 ${filtered.length}개", 
          style: const TextStyle(fontSize: 11, color: Colors.grey)), 
      trailing: const Icon(Icons.chevron_right), 
      onTap: () {
        if (filtered.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ArticleListScreen(articles: filtered, treatyName: n))
          ).then((_) => setState(() {}));
        }
      }
    ),
  );
}
  // 1. 조문 암기 모드 시작 전 선택 팝업
  void _startFullTextQuiz() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("조문 암기 모드", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text("어떤 방식으로 학습하시겠습니까?"),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          // 객관식 선택
          SizedBox(
            width: 100,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black, elevation: 0),
              onPressed: () {
                Navigator.pop(ctx);
                _startQuiz("FULL_TEXT", quizType: "MCQ"); // 객관식 인자 전달
              },
              child: const Text("객관식"),
            ),
          ),
          // 주관식 선택
          SizedBox(
            width: 100,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white, elevation: 0),
              onPressed: () {
                Navigator.pop(ctx);
                _startQuiz("FULL_TEXT", quizType: "SHORT"); // 주관식 인자 전달
              },
              child: const Text("주관식"),
            ),
          ),
        ],
      ),
    );
  }
  void _startQuiz(String mode, {String? quizType}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          allArticles: _allArticles, 
          mode: mode, 
          quizType: quizType // QuizScreen 클래스에도 이 변수가 있어야 합니다.
        ),
      ),
    ).then((_) => setState(() {}));
  }
}

// --- [2. 즐겨찾기 리스트 화면] ---

class FavoriteListScreen extends StatelessWidget {
  final List<Paragraph> favorites;
  final List<Article> allArticles;
  const FavoriteListScreen({super.key, required this.favorites, required this.allArticles});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("즐겨찾기 조문")),
      body: ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: favorites.length,
        itemBuilder: (context, i) {
          final p = favorites[i];
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
            child: ListTile(
              title: Text("${p.parentTreaty} - ${p.parentArticleId}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), 
              subtitle: Text(p.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final target = allArticles.firstWhere((a) => a.id == p.parentArticleId && a.treaty == p.parentTreaty);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: target)));
              },
            ),
          );
        },
      ),
    );
  }
}

// --- [3. 퀴즈 시스템 (계층적 로직 반영)] ---

class QuizScreen extends StatefulWidget {
  final List<Article> allArticles;
  final String mode;
  final String? quizType; // 이 줄을 추가하세요.

  // 생성자에 quizType 추가
  const QuizScreen({super.key, required this.allArticles, required this.mode, this.quizType});

  @override State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late Set<String> _selectedTreaties;
  List<Map<String, dynamic>> _quizzes = [];
  List<Map<String, dynamic>> _wrongSession = [];
  int _idx = 0; int _score = 0; int _lives = 5; int _combo = 0;
  bool _revealed = false; bool _isCorrect = false; bool _isFinished = false;
  final TextEditingController _ansCtrl = TextEditingController();
  
  List<String> _makeOptions(String correctAns) {
  List<String> options = [correctAns];
  List<String> allPossibleTexts = [];

  // 모든 조약의 항, 호, 목 텍스트를 수집
  for (var a in widget.allArticles) {
    for (var p in a.paragraphs) {
      allPossibleTexts.add(p.text);
      for (var item in p.subItems) {
        allPossibleTexts.add(item.text);
        for (var pt in item.subPoints) {
          allPossibleTexts.add(pt.text);
        }
      }
    }
  }

  allPossibleTexts.remove(correctAns); // 정답 제외
  allPossibleTexts.shuffle();

  // 중복되지 않는 오답 3개 선택
  int i = 0;
  while (options.length < 4 && i < allPossibleTexts.length) {
    if (!options.contains(allPossibleTexts[i])) {
      options.add(allPossibleTexts[i]);
    }
    i++;
  }
  
  options.shuffle(); // 보기 순서 섞기
  return options;
} 
  @override
  void initState() { 
    super.initState(); 
    _selectedTreaties = widget.allArticles.map((a) => a.treaty).toSet();
    _generate(); 
  }

  void _generate() {
  _quizzes = [];
  for (var a in widget.allArticles) {
    if (!_selectedTreaties.contains(a.treaty)) continue;
    for (var p in a.paragraphs) {
      if (widget.mode == "CHECK" && p.wrongCount == 0) continue;
      if (widget.mode == "IMPORTANT" && !p.isFavorite) continue;
      
      // --- [조문 암기 모드 전용 로직] ---
      // _generate() 내부 FULL_TEXT 분기 수정 예시
if (widget.mode == "FULL_TEXT") {
  // 1. [항] 문제
  _quizzes.add({
    "location": "${a.id} ${a.title}",
    "article": a, 
    "paragraph": p,
    "type": "PARA", // 현재 문제 유형
    "ans": p.text,
  });

  for (var item in p.subItems) {
    // 2. [호] 문제
    _quizzes.add({
      "location": "${a.id} ${a.title}",
      "article": a, 
      "paragraph": p,
      "subItem": item, // 현재 문제 대상 호
      "type": "ITEM",
      "ans": item.text,
    });

    for (var pt in item.subPoints) {
      // 3. [목] 문제
      _quizzes.add({
        "location": "${a.id} ${a.title}",
        "article": a, 
        "paragraph": p,
        "subItem": item,
        "subPoint": pt, // 현재 문제 대상 목
        "type": "POINT",
        "ans": pt.text,
      });
    }
  }
}
  else { 
        for (var k in p.keywords) {
          if (k.isEmpty) continue;

          // 1. [항] 키워드 문제
          if (p.text.contains(k)) {
            _quizzes.add({
              "location": "${a.id} ${a.title}",
              "article": a, "paragraph": p,
              "parentTexts": [], 
              "targetText": "제 ${p.order} 항: ${p.text.replaceAll(k, " [ ??? ] ")}",
              "ans": k, "subInfo": "항"
            });
          }

          // 2. [호/목] 키워드 문제
          for (var item in p.subItems) {
            if (item.text.contains(k)) {
              _quizzes.add({
                "location": "${a.id} ${a.title}",
                "article": a, "paragraph": p,
                "parentTexts": ["제 ${p.order} 항: ${p.text}"],
                "targetText": "${item.number}) ${item.text.replaceAll(k, " [ ??? ] ")}",
                "ans": k, "subInfo": "호"
              });
            }
            for (var pt in item.subPoints) {
              if (pt.text.contains(k)) {
                _quizzes.add({
                  "location": "${a.id} ${a.title}",
                  "article": a, "paragraph": p,
                  "parentTexts": ["제 ${p.order} 항: ${p.text}", "${item.number}) ${item.text}"],
                  "targetText": "${pt.letter}. ${pt.text.replaceAll(k, " [ ??? ] ")}",
                  "ans": k, "subInfo": "목"
                });
              }
            }
          }
        }
      } // --- [else 종료] ---
    }
  }

  // --- [후처리: 객관식 보기 생성 및 섞기] ---
  if (widget.quizType == "MCQ") {
    for (var q in _quizzes) {
      q['options'] = _makeOptions(q['ans']);
    }
  }
  _quizzes.shuffle();
  setState(() { _idx = 0; _lives = 5; _score = 0; _isFinished = false; _wrongSession = []; });
}
  
  void _checkAnswer() {
    // 이미 결과가 나왔으면 무시
    if (_revealed) return;
    
    // 주관식인데 입력값이 비어있으면 무시
    if (widget.quizType == "SHORT" && _ansCtrl.text.trim().isEmpty) return;

    setState(() {
      _revealed = true;
      
      String userInput = _ansCtrl.text.replaceAll(' ', '').toLowerCase();
      String actualAnswer = _quizzes[_idx]['ans'].toString().replaceAll(' ', '').toLowerCase();

      _isCorrect = (userInput == actualAnswer);

      if (_isCorrect) {
        _combo++;
        _score += 10 + (_combo * 2);
      } else {
        _combo = 0;
        _lives--;
        _quizzes[_idx]['paragraph'].wrongCount++; 
        _wrongSession.add(_quizzes[_idx]); 
      }
      
      if (_lives <= 0) _isFinished = true;
    });
  }

  void _showSettings() {
    // 현재 데이터에 포함된 모든 조약(Treaty) 리스트 추출
    final treaties = widget.allArticles.map((a) => a.treaty).toSet().toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("출제 범위 설정", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: treaties.map((t) => CheckboxListTile(
                title: Text(t, style: const TextStyle(fontSize: 14)),
                value: _selectedTreaties.contains(t),
                activeColor: const Color(0xFF1B5E20),
                onChanged: (v) {
                  setS(() {
                    if (v!) _selectedTreaties.add(t);
                    else _selectedTreaties.remove(t);
                  });
                },
              )).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _generate(); // 설정 변경 후 문제 다시 생성 (중요!)
                Navigator.pop(ctx);
                setState(() {}); // 화면 갱신
              },
              child: const Text("적용", style: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    if (_quizzes.isEmpty) return Scaffold(appBar: AppBar(), body: const Center(child: Text("출제할 문제가 없습니다.")));
    if (_isFinished) return _buildResult();

    final q = _quizzes[_idx];
    // 부모 힌트(상위 계층)와 자식 힌트(하위 계층)를 합칩니다.
    final List<String> displayHints = [
      ...List<String>.from(q['parentTexts'] ?? []),
      ...List<String>.from(q['hints'] ?? [])
    ];

    return Scaffold(
      appBar: AppBar(title: Text(widget.mode), actions: [IconButton(icon: const Icon(Icons.settings), onPressed: _showSettings)]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- [1. 상태 바: 점수 & 하트] ---
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("SCORE : $_score", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Row(children: [
                if (_combo > 0) Text("$_combo COMBO 🔥 ", style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w900, fontSize: 13)),
                ...List.generate(5, (i) => Icon(i < _lives ? Icons.favorite : Icons.favorite_border, color: const Color(0xFF1B5E20), size: 18)),
              ]),
            ]),
            const SizedBox(height: 20),

           // --- [2. 문제 카드 영역] ---
// --- [2. 문제 카드 영역] ---
Container(
  width: double.infinity,
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: const Color(0xFFF1F8E9), 
    borderRadius: BorderRadius.circular(20), 
    border: Border.all(color: const Color(0xFFC8E6C9))
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, 
    children: [
      // 1. 상단 위치 정보
      Text(q['location'], style: const TextStyle(fontSize: 12, color: Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
      const Divider(height: 25, color: Color(0xFFC8E6C9)),

      // 2. [항] 출력
      _buildHierarchyLine(
        prefix: "제 ${q['paragraph'].order} 항 ",
        fullText: q['paragraph'].text,
        // 암기모드 정답이거나, 키워드 모드에서 '항'에 문제가 걸렸을 때
        isTarget: q['type'] == "PARA" || q['subInfo'] == "항",
        q: q,
      ),

      // 3. [호/목] 출력
      ...(q['paragraph'] as Paragraph).subItems.map((item) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 8),
              child: _buildHierarchyLine(
                prefix: "${item.number}) ",
                fullText: item.text,
                // 암기모드 정답이거나, 키워드 모드에서 이 '호'가 문제일 때
                isTarget: q['subItem'] == item || (q['subInfo'] == "호" && item.text.contains(q['ans'].toString())),
                q: q,
              ),
            ),
            // [목] 출력
            ...item.subPoints.map((pt) => Padding(
              padding: const EdgeInsets.only(left: 20, top: 4),
              child: _buildHierarchyLine(
                prefix: "${pt.letter}) ",
                fullText: pt.text,
                // 암기모드 정답이거나, 키워드 모드에서 이 '목'이 문제일 때
                isTarget: q['subPoint'] == pt || (q['subInfo'] == "목" && pt.text.contains(q['ans'].toString())),
                q: q,
              ),
            )),
          ],
        );
      }).toList(),
    ],
  ),
),
            const SizedBox(height: 25),

            // --- [3. 입력 영역: 객관식 vs 주관식 분기] ---
            if (widget.quizType == "MCQ")
              // 객관식 버튼 리스트
              Column(
                children: (q['options'] as List<String>).map((opt) {
                  Color btnColor = Colors.white;
                  Color textColor = Colors.black87;
                  Color borderColor = const Color(0xFFC8E6C9);
                  double borderWeight = 1.0;

                  if (_revealed) {
                    if (opt == q['ans']) {
                      btnColor = const Color(0xFFE8F5E9); 
                      textColor = const Color(0xFF2E7D32);
                      borderColor = const Color(0xFF2E7D32);
                      borderWeight = 2.5;
                    } else {
                      btnColor = const Color(0xFFFFEBEE);
                      textColor = const Color(0xFFC62828);
                      borderColor = const Color(0xFFC62828);
                      borderWeight = 1.5;
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: btnColor,
                          padding: const EdgeInsets.all(15),
                          side: BorderSide(color: borderColor, width: borderWeight),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _revealed ? null : () { 
                          _ansCtrl.text = opt; 
                          _checkAnswer(); 
                        },
                        child: Text(opt, style: TextStyle(color: textColor, fontSize: 13)),
                      ),
                    ),
                  );
                }).toList(),
              )
            else
              // 주관식 입력창 + 제출 버튼
              Column(
                children: [
                  TextField(
                    controller: _ansCtrl, 
                    enabled: !_revealed, 
                    maxLines: widget.mode == "FULL_TEXT" ? 3 : 1,
                    decoration: InputDecoration(
                      hintText: "정답을 입력하세요", 
                      filled: true, 
                      fillColor: Colors.grey.shade100, 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)
                    ),
                    onSubmitted: (_) => _checkAnswer(),
                  ),
                  if (!_revealed) ...[
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _checkAnswer, 
                        child: const Text("정답 확인", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),

            // --- [4. 결과 영역: 정답 확인 후 나타나는 다음 문제 버튼] ---
            if (_revealed) ...[
              const SizedBox(height: 20),
              // 주관식일 때만 정답 박스 표시
              if (widget.quizType == "SHORT" || widget.quizType == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _isCorrect ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _isCorrect ? Colors.green.shade700 : Colors.red.shade700, width: 2),
                  ),
                  child: Column(children: [
                    Text(_isCorrect ? "O" : "X", style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: _isCorrect ? Colors.green.shade700 : Colors.red.shade700)),
                    const SizedBox(height: 8),
                    Text("${q['ans']}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ]),
                ),
              const SizedBox(height: 25),
              // 공통: 다음 문제 버튼
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(220, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () {
                    setState(() {
                      if (_idx + 1 < _quizzes.length) {
                        _idx++; _revealed = false; _ansCtrl.clear();
                      } else {
                        _isFinished = true;
                      }
                    });
                  },
                  child: Text((_idx + 1 < _quizzes.length) ? "다음 문제" : "결과 확인", style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
            ], // <-- if (_revealed) 닫음
          ], // <-- Column children 닫음
        ), // <-- Column 닫음
      ), // <-- SingleChildScrollView 닫음
    );
  }
  Widget _buildResult() => Scaffold(
    backgroundColor: Colors.white, // 전체 배경 흰색으로 통일
    body: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            const Icon(Icons.emoji_events, size: 100, color: Colors.amber),
            const SizedBox(height: 10),
            const Text("QUIZ FINISHED!", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20), letterSpacing: 1.5)),
            const SizedBox(height: 5),
            Text("최종 점수: $_score", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            
            // 오답 확인 버튼 (오답이 있을 때만 표시)
            if (_wrongSession.isNotEmpty) ...[
              SizedBox(
                width: 220,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red.shade700,
                    elevation: 0,
                    side: BorderSide(color: Colors.red.shade200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () => _showWrongReview(), 
                  icon: const Icon(Icons.history_edu),
                  label: const Text("오답 리스트 확인", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 메인으로 돌아가기 버튼 (초록색 박스 디자인)
            SizedBox(
              width: 220,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20), // 테마색인 진한 초록색
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () => Navigator.pop(context), 
                child: const Text("메인 화면으로 돌아가기", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _showWrongReview() {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => Container(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const Text("오답 리스트", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(),
        Expanded(child: ListView.builder(itemCount: _wrongSession.length, itemBuilder: (_, i) {
          final item = _wrongSession[i];
          final p = item['paragraph'] as Paragraph;
          return ListTile(
            title: Text(item['location']), 
            subtitle: Text("정답: ${item['ans']}"),
            trailing: Text("누적 오답: ${p.wrongCount}회", style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
          );
        })),
      ]),
    ));
  }
  
  Widget _buildHierarchyLine({
  required String prefix,
  required String fullText,
  required bool isTarget,
  required Map q,
}) {
  String displayContent = fullText;

  if (isTarget) {
    if (widget.mode == "FULL_TEXT") {
      // 1. 조문 암기 모드: 문장 전체를 가림
      displayContent = " [       ???        ] ";
    } else {
      // 2. 일반/키워드 모드: 정답 키워드만 [ ??? ]로 치환
      // q['ans']가 문장에 포함되어 있을 때만 치환
      String answer = q['ans'].toString();
      if (fullText.contains(answer)) {
        displayContent = fullText.replaceAll(answer, " [ ??? ] ");
      }
    }
  }

  return RichText(
    text: TextSpan(
      // family 대신 fontFamily를 사용하거나, 특정 폰트가 없다면 fontFamily 줄을 삭제하세요.
      style: const TextStyle(
        color: Colors.black87, 
        height: 1.5, 
        fontSize: 13, 
        fontFamily: 'Pretendard', // ← 여기서 family를 fontFamily로 수정!
      ), 
      children: [
        // '제 1항' 같은 앞부분 (진하게)
        TextSpan(
          text: prefix, 
          style: const TextStyle(fontWeight: FontWeight.bold)
        ),
        // 실제 본문 내용 (문제인 경우 하이라이트)
        TextSpan(
          text: displayContent,
          style: TextStyle(
            color: isTarget ? const Color(0xFF1B5E20) : Colors.black54,
            fontWeight: isTarget ? FontWeight.w900 : FontWeight.normal,
            // 문제 줄만 연한 녹색 배경을 깔아줍니다.
            backgroundColor: null,
          ),
        ),
      ],
    ),
  );
}
}

// --- [4. 조문 리스트 화면 (검색 기능 복구)] ---

class ArticleListScreen extends StatefulWidget {
  final List<Article> articles;
  final String treatyName;
  const ArticleListScreen({super.key, required this.articles, required this.treatyName});

  @override
  State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  String _query = "";

  @override
  Widget build(BuildContext context) {
    // 검색 필터링 로직
    final filtered = widget.articles.where((a) {
      final q = _query.toLowerCase();
      return a.id.contains(q) || 
             a.title.toLowerCase().contains(q) || 
             a.paragraphs.any((p) => p.text.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.treatyName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(children: [
        // 1. 검색바 영역 (슬림하고 깔끔한 디자인)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: "번호, 제목, 내용 검색...",
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF1B5E20)),
              filled: true,
              fillColor: Colors.grey.shade100,
              isDense: true, // 세로 높이 축소
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),

        // 2. 조문 리스트 영역
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: filtered.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1, 
              indent: 56, // 아이콘 너비만큼 들여쓰기해서 구분선 처리
              color: Color(0xFFE8F5E9),
            ),
            itemBuilder: (context, i) {
              final article = filtered[i];
              // 항들 중 하나라도 즐겨찾기(isFavorite)가 되어 있는지 확인
              final isFav = article.paragraphs.any((p) => p.isFavorite);

              return ListTile(
                // 좌측: 초록색 북마크 아이콘
                leading: Icon(
                  isFav ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                  color: isFav ? const Color(0xFF1B5E20) : Colors.grey.shade300,
                  size: 24,
                ),
                // 중앙: 조항 번호 및 제목
                title: Text(
                  "${article.id} ${article.title}",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isFav ? FontWeight.bold : FontWeight.w500,
                    color: isFav ? const Color(0xFF1B5E20) : Colors.black87,
                  ),
                ),
                // 우측: 상세 페이지 이동 화살표
                trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)),
                  ).then((_) {
                    // 상세 페이지에서 즐겨찾기 변경 후 돌아왔을 때 리스트 UI 갱신
                    setState(() {});
                  });
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// --- [5. 조문 상세 화면 (키워드/필기 하단 통합)] ---

class ArticleDetailScreen extends StatefulWidget {
  final Article article;
  const ArticleDetailScreen({super.key, required this.article});
  @override State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.article.treaty} ${widget.article.id}")),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(widget.article.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
        const Divider(height: 30),
        ...widget.article.paragraphs.map((p) => _buildParagraphItem(p)).toList(),
      ]),
    );
  }

  Widget _buildParagraphItem(Paragraph p) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text("제 ${p.order} 항", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1B5E20))),
        Row(children: [
          // 1. 즐겨찾기 아이콘: 활성화 시 진한 초록, 해제 시 연한 초록 테두리
          IconButton(
            icon: Icon(
              p.isFavorite ? Icons.star : Icons.star_border, 
              color: p.isFavorite ? const Color(0xFF2E7D32) : Colors.green.shade200,
            ), 
            onPressed: () => setState(() => p.isFavorite = !p.isFavorite)
          ),
          // 2. 필기 아이콘: 깔끔한 초록색으로 변경
          IconButton(
            icon: const Icon(Icons.edit_note, color: Color(0xFF43A047)), 
            onPressed: () => _showEditNote(p)
          ),
        ])
      ]),
      Text(p.text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      
      ...p.subItems.map((s) => Padding(
        padding: const EdgeInsets.only(left: 15, top: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("${s.number}. ${s.text}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ...s.subPoints.map((pt) => Padding(
            padding: const EdgeInsets.only(left: 15, top: 5),
            child: Text("${pt.letter}. ${pt.text}", style: const TextStyle(fontSize: 13, color: Colors.black)),
          )).toList(),
        ]),
      )).toList(),

      const SizedBox(height: 15),
      if (p.userNote.isNotEmpty) 
        Container(width: double.infinity, padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.yellow.shade50, borderRadius: BorderRadius.circular(8)), child: Text("📝 ${p.userNote}", style: const TextStyle(fontSize: 12))),
      
      Wrap(
  spacing: 8, 
  runSpacing: 8, 
  children: [
    // --- 1. 등록된 키워드 칩 (진한 초록, 더 둥글게) ---
    ...p.keywords.map((k) => Chip(
      label: Text(
        k, 
        style: const TextStyle(
          fontSize: 10, 
          color: Colors.white, 
          fontWeight: FontWeight.w600
        )
      ),
      backgroundColor: const Color(0xFF1B5E20),
      deleteIcon: const Icon(Icons.close, size: 12, color: Colors.white70),
      onDeleted: () => setState(() => p.keywords.remove(k)),
      // ★ BorderRadius를 8에서 30으로 변경하여 알약 모양으로 ★
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      side: BorderSide.none, 
      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
    )),
    
    // --- 2. 키워드 추가 버튼 (연한 초록 배경 + 테두리, 더 둥글게) ---
    ActionChip(
      label: const Text(
        "키워드 추가 +", 
        style: TextStyle(
          fontSize: 10, 
          fontWeight: FontWeight.bold, 
          color: Color(0xFF1B5E20)
        )
      ),
      backgroundColor: const Color(0xFFF1F8E9),
      // ★ 동일하게 BorderRadius 30 적용 ★
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: const BorderSide(color: Color(0xFFC8E6C9)), // 테두리 유지
      ),
      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
      onPressed: () => _showAddKeyword(p.keywords),
    ),
  ],
),
const Divider(height: 40),
    ]);
  }

  void _showAddKeyword(List<String> targetList) {
    final c = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("키워드 추가"), content: TextField(controller: c), actions: [TextButton(onPressed: () { if(c.text.isNotEmpty) setState(() => targetList.add(c.text)); Navigator.pop(ctx); }, child: const Text("추가"))]));
  }

  void _showEditNote(Paragraph p) {
    final c = TextEditingController(text: p.userNote);
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("필기"), content: TextField(controller: c, maxLines: 3), actions: [TextButton(onPressed: () { setState(() => p.userNote = c.text); Navigator.pop(ctx); }, child: const Text("저장"))]));
  }
}
