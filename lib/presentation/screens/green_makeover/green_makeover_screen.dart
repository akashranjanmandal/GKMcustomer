import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../theme/theme.dart';

class GreenMakeoverScreen extends StatefulWidget {
  const GreenMakeoverScreen({super.key});

  @override
  State<GreenMakeoverScreen> createState() => _GreenMakeoverScreenState();
}

class _GreenMakeoverScreenState extends State<GreenMakeoverScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _canLoadImages = false;

  @override
  void initState() {
    super.initState();
    // Delay heavy image loading until after the slide transition completes to prevent lag
    Future.delayed(350.ms, () {
      if (mounted) setState(() => _canLoadImages = true);
    });
  }

  void _openWhatsApp() async {
    const url =
        'https://wa.me/919876543210?text=Hi%20GharKaMali!%20I%20want%20to%20know%20about%20the%20Green%20Makeover%20package.';
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFAFAFA); // Pure light theme background

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Subtle background orbs (No heavy blurs!)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: C.forest.withOpacity(0.06), blurRadius: 100)
                ],
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1, end: 1.2, duration: 6.seconds)
                .fadeIn(),
          ),
          Positioned(
            bottom: 200,
            left: -150,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: C.gold.withOpacity(0.03), blurRadius: 100)
                ],
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1, end: 1.3, duration: 8.seconds),
          ),

          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildSpaces(),
                    const SizedBox(height: 64),
                    _buildConsultationBanner(),
                    const SizedBox(height: 64),
                    _buildServices(),
                    const SizedBox(height: 64),
                    _buildTransformations(),
                    const SizedBox(height: 64),
                    _buildPricing(),
                    const SizedBox(height: 64),
                    _buildWhyChooseUs(),
                    const SizedBox(height: 140), // Bottom padding
                  ],
                ),
              ),
            ],
          ),

          _buildStickyBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: const Color(0xFFFAFAFA),
      surfaceTintColor: const Color(0xFFFAFAFA),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
              color: Colors.black12, shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back, color: Colors.black87, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text('Green Makeover',
          style: p(17, w: FontWeight.w800, color: Colors.black87)),
    );
  }

  Widget _buildConsultationBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 30,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Start with Just ₹299',
              style: p(24, w: FontWeight.w900, color: C.forest, ls: -0.5)),
          const SizedBox(height: 12),
          Text('Book a professional site visit & consultation.',
              style: p(15, w: FontWeight.w500, color: Colors.black54)),
          const SizedBox(height: 24),
          _glassCheck('Space assessment & layout design'),
          _glassCheck('Plant recommendations for your climate'),
          _glassCheck('Detailed budget planning'),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: C.forest.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: C.forest.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: C.forest.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.bolt, color: C.forest, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '100% Adjustable in your final project cost. Zero risk.',
                    style: p(14, w: FontWeight.w800, color: C.forest, h: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _glassCheck(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: C.forest.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check, color: C.forest, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: p(14, w: FontWeight.w500, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildServices() {
    final services = [
      {
        'icon': Icons.architecture,
        'title': 'Space Planning',
        'desc': 'Custom designs suitable for your space dimensions.'
      },
      {
        'icon': Icons.eco,
        'title': 'Plant Selection',
        'desc': 'Choosing the right plants based on light and climate.'
      },
      {
        'icon': Icons.format_paint,
        'title': 'Designer Pots',
        'desc': 'Aesthetic pots and planters that match your interior.'
      },
      {
        'icon': Icons.auto_awesome_mosaic,
        'title': 'Arrangements',
        'desc': 'Tiered stands and visually pleasing compositions.'
      },
      {
        'icon': Icons.local_shipping,
        'title': 'Delivery',
        'desc': 'Safe transportation of all plants and materials.'
      },
      {
        'icon': Icons.handyman,
        'title': 'Installation',
        'desc': 'End-to-end setup by trained professionals.'
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text('End-to-End Solutions',
              style: p(24, w: FontWeight.w900, color: Colors.black87)),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final svc = services[index];
              return Container(
                width: 170,
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 5))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: C.forest.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(svc['icon'] as IconData,
                          color: C.forest, size: 24),
                    ),
                    const Spacer(),
                    Text(svc['title'] as String,
                        style: p(16,
                            w: FontWeight.w800, color: Colors.black87, h: 1.2)),
                    const SizedBox(height: 8),
                    Text(svc['desc'] as String,
                        style: p(12, color: Colors.black54, h: 1.4),
                        maxLines: 3),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: (100 * index).ms)
                  .slideX(begin: 0.1, end: 0);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSpaces() {
    final spaces = [
      {'title': 'Balcony',  'img': 'assets/images/balcony.jpeg'},
      {'title': 'Indoor',   'img': 'assets/images/indoor.jpeg'},
      {'title': 'Lawn',     'img': 'assets/images/Lawn.jpeg'},
      {'title': 'Terrace',  'img': 'assets/images/terrace.jpeg'},
      {'title': 'Backyard', 'img': 'assets/images/backyard.jpeg'},
      {'title': 'Office',   'img': 'assets/images/office_mobile.jpeg'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text('Spaces We Transform',
              style: p(24, w: FontWeight.w900, color: Colors.black87)),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 380,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.85),
            physics: const BouncingScrollPhysics(),
            itemCount: spaces.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 20,
                        offset: Offset(0, 10))
                  ],
                  image: DecorationImage(
                    image: AssetImage(spaces[index]['img']!),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                      stops: [0.5, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(spaces[index]['title']!,
                            style:
                                p(24, w: FontWeight.w900, color: Colors.white)),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_forward,
                            color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTransformations() {
    if (!_canLoadImages) return const SizedBox(height: 340);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text('Our Transformations',
              style: p(24, w: FontWeight.w900, color: Colors.black87)),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text('Swipe to see the magic we bring to life.',
              style: p(14, color: Colors.black54)),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 340,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: 16,
            itemBuilder: (context, index) {
              return Container(
                width: 260,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image(
                    image: ResizeImage(
                        AssetImage('assets/images/img-${index + 1}.jpeg'),
                        width: 500),
                    fit: BoxFit.cover,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: (50 * index).ms)
                  .slideX(begin: 0.1, end: 0);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPricing() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Curated Packages',
              style: p(24, w: FontWeight.w900, color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Fully customized to your space size and aesthetic.',
              style: p(14, color: Colors.black54)),
          const SizedBox(height: 32),
          _priceCard('Basic Setup', '20,000',
              'Essential plants & standard pots for cozy spaces.', false),
          _priceCard('Premium Setup', '35,000',
              'Curated design with designer pots & stands.', true),
          _priceCard('Luxury Setup', '50,000',
              'Rare plants, imported pots & architectural layout.', false),
        ],
      ),
    );
  }

  Widget _priceCard(String title, String price, String desc, bool isPremium) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isPremium ? C.forest : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border:
            Border.all(color: isPremium ? Colors.transparent : Colors.black12),
        boxShadow: isPremium
            ? [
                BoxShadow(
                    color: C.forest.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10))
              ]
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 5))
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPremium)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                  color: C.gold, borderRadius: BorderRadius.circular(12)),
              child: Text('MOST POPULAR',
                  style: p(10, w: FontWeight.w900, color: C.forest, ls: 1)),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .shimmer(duration: 2.seconds, color: Colors.white54),
          Text(title,
              style: p(20,
                  w: FontWeight.w900,
                  color: isPremium ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Starting ',
                  style: p(14,
                      color: isPremium ? Colors.white70 : Colors.black54)),
              Text('₹$price',
                  style: p(32,
                      w: FontWeight.w900,
                      color: isPremium ? Colors.white : C.forest,
                      ls: -1)),
            ],
          ),
          const SizedBox(height: 16),
          Text(desc,
              style: p(14,
                  color: isPremium ? Colors.white70 : Colors.black54, h: 1.5)),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildWhyChooseUs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Why GharKaMali',
              style: p(24, w: FontWeight.w900, color: Colors.black87)),
          const SizedBox(height: 24),
          _whyItem(Icons.tune, '100% Customized designs'),
          _whyItem(Icons.park, 'Expert plant selection for Indian weather'),
          _whyItem(Icons.task_alt, 'End-to-end hassle-free execution'),
          _whyItem(Icons.favorite, 'Built for long-term plant health'),
        ],
      ),
    );
  }

  Widget _whyItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5))
              ],
            ),
            child: Icon(icon, color: C.forest),
          ),
          const SizedBox(width: 20),
          Expanded(
              child: Text(text,
                  style: p(15, w: FontWeight.w600, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, -10))
          ],
        ),
        child: GestureDetector(
          onTap: _openWhatsApp,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: C.forest,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: C.forest.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat_bubble, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Text('Book Consultation',
                    style: p(18, w: FontWeight.w900, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    ).animate().slideY(begin: 1, end: 0, curve: Curves.easeOutQuart);
  }
}
