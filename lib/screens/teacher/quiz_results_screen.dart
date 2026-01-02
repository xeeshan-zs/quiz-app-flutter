import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/quiz_model.dart';
import '../../models/result_model.dart';
import '../../services/firestore_service.dart';

class QuizResultsScreen extends StatefulWidget {
  final QuizModel quiz;

  const QuizResultsScreen({super.key, required this.quiz});

  @override
  State<QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends State<QuizResultsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterClass = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Header / Hero Section
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(32, 60, 32, 40),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1B2E), // Match Teacher Dashboard Dark Theme
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF2E236C),
                    Color(0xFF433D8B),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(), 
                        icon: const Icon(Icons.arrow_back, color: Colors.white)
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Quiz Results',
                        style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 48.0),
                    child: Text(
                      'Results for: ${widget.quiz.title}',
                      style: const TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search / Filter and Table
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Modern Search Bar
                   Container(
                     decoration: BoxDecoration(
                       color: Colors.white,
                       borderRadius: BorderRadius.circular(30),
                       boxShadow: [
                         BoxShadow(
                           color: Colors.black.withValues(alpha: 0.05),
                           blurRadius: 10,
                           offset: const Offset(0, 4),
                         ),
                       ],
                     ),
                     child: TextField(
                       controller: _searchController,
                       decoration: InputDecoration(
                         hintText: 'Filter by Class (e.g. BSCS-4B)',
                         hintStyle: TextStyle(color: Colors.grey[400]),
                         prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                         border: InputBorder.none,
                         enabledBorder: InputBorder.none,
                         focusedBorder: InputBorder.none,
                         contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                         fillColor: Colors.transparent, 
                       ),
                       onChanged: (val) {
                         setState(() {
                           _filterClass = val;
                         });
                       },
                     ),
                   ),
                   const SizedBox(height: 32),

                   // Results Table Container
                   Container(
                     decoration: BoxDecoration(
                       color: Colors.white,
                       borderRadius: BorderRadius.circular(16),
                       border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                       boxShadow: [
                         BoxShadow(
                           color: Colors.black.withValues(alpha: 0.05),
                           blurRadius: 15,
                           offset: const Offset(0, 5),
                         )
                       ],
                     ),
                     clipBehavior: Clip.antiAlias,
                     child: StreamBuilder<List<ResultModel>>(
                       stream: firestoreService.getResultsByQuizId(widget.quiz.id),
                       builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          }

                          final allResults = snapshot.data ?? [];
                          // Filter results
                          final filteredResults = allResults.where((r) {
                            if (_filterClass.isEmpty) return true;
                            return r.className.toLowerCase().contains(_filterClass.toLowerCase());
                          }).toList();
                          
                          // Sort by submitted time (newest first)
                          filteredResults.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

                          if (filteredResults.isEmpty) {
                             return Container(
                               padding: const EdgeInsets.all(60),
                               alignment: Alignment.center,
                               child: Column(
                                 children: [
                                   Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
                                   const SizedBox(height: 16),
                                   Text('No results found', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                                 ],
                               ),
                             );
                          }

                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 48), // Ensure full width
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFF2E236C)), // Dark Header
                                headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                                dataRowMinHeight: 60,
                                dataRowMaxHeight: 60,
                                columnSpacing: 40,
                                horizontalMargin: 30,
                                dividerThickness: 0.5,
                                columns: const [
                                  DataColumn(label: Text('Student Name')),
                                  DataColumn(label: Text('Roll No')),
                                  DataColumn(label: Text('Class')),
                                  DataColumn(label: Text('Score')),
                                  DataColumn(label: Text('Submitted At')),
                                ],
                                rows: filteredResults.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final result = entry.value;
                                  final isEven = index % 2 == 0;
                                  
                                  return DataRow(
                                    color: WidgetStateProperty.resolveWith((states) {
                                      // Alternating row colors
                                      return isEven ? const Color(0xFFF9FAFB) : Colors.white; 
                                    }),
                                    cells: [
                                      DataCell(
                                        Text(
                                          result.studentName.isNotEmpty ? result.studentName : 'Unknown', 
                                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1F2937))
                                        )
                                      ),
                                      DataCell(Text(result.studentRollNumber, style: const TextStyle(color: Color(0xFF4B5563)))),
                                      DataCell(Text(result.className, style: const TextStyle(color: Color(0xFF4B5563)))),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEDE9FE), // Light Purple
                                            borderRadius: BorderRadius.circular(20)
                                          ),
                                          child: Text(
                                            '${result.score} / ${result.totalMarks}', 
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold, 
                                              color: Color(0xFF5B21B6), // Darker Purple
                                              fontSize: 13
                                            )
                                          ),
                                        )
                                      ),
                                      DataCell(Text(
                                        DateFormat('MMM dd, yyyy, hh:mm a').format(result.submittedAt),
                                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)
                                      )),
                                    ]
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                       },
                     ),
                   ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
