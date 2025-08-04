import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_screen.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  _OnboardingPageState createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _onboardingData = [
    OnboardingData(
      title: "Selamat Datang di Hair Magic!",
      description: "Ubah penampilanmu dengan gaya rambut impian menggunakan kekuatan AI.",
      image: "asset/Asset/Images/onboarding-images.jpeg",
    ),
    OnboardingData(
      title: "Tiga Langkah Mudah",
      description: "Cukup unggah foto wajah, pilih gaya dan warna rambut yang kamu inginkan.",
      image: "asset/Asset/Images/onboarding-images.jpeg",
    ),
    OnboardingData(
      title: "Lihat Keajaibannya!",
      description: "Biarkan Aileen's Magic bekerja dan lihat hasilnya dalam sekejap. Ayo mulai!",
      image: "asset/Asset/Images/onboarding-images.jpeg",
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _onboardingData.length,
                  onPageChanged: (int page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  itemBuilder: (context, index) {
                    return OnboardingItem(data: _onboardingData[index]);
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _buildPageIndicator(),
              ),
              const SizedBox(height: 40),
              _buildBottomButtons(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPageIndicator() {
    List<Widget> list = [];
    for (int i = 0;
    i < _onboardingData.length;
    i++) {
      list.add(i == _currentPage ? _indicator(true) : _indicator(false));
    }
    return list;
  }

  Widget _indicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 8,
      width: isActive ? 24 : 8,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      decoration: BoxDecoration(
        color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildBottomButtons() {
    if (_currentPage == _onboardingData.length - 1) {
      return ElevatedButton(
        onPressed: _completeOnboarding,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          textStyle: const TextStyle(fontSize: 16),
        ),
        child: const Text("Mulai Sekarang"),
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _completeOnboarding,
            child: const Text("Lewati"),
          ),
          ElevatedButton(
            child: const Text("Selanjutnya"),
            onPressed: () {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              );
            },
          ),
        ],
      );
    }
  }
}

class OnboardingData {
  final String title;
  final String description;
  final String image;
  OnboardingData({required this.title, required this.description, required this.image});
}

class OnboardingItem extends StatelessWidget {
  final OnboardingData data;
  const OnboardingItem({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Image.asset(data.image, fit: BoxFit.contain),
        ),
        const SizedBox(height: 40),
        Text(
          data.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          data.description,
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}