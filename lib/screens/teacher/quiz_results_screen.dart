import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/quiz_model.dart';
import '../../models/result_model.dart';
import '../../services/firestore_service.dart';
import '../../providers/user_provider.dart';
import '../../widgets/quiz_app_bar.dart';
import '../../widgets/quiz_app_drawer.dart';

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
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: QuizAppBar(user: user, isTransparent: true),
      drawer: QuizAppDrawer(user: user),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: StreamBuilder<List<ResultModel>>(
        stream: firestoreService.getResultsByQuizId(widget.quiz.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
           if (snapshot.hasError) {
             return Center(child: Text('Error: ${snapshot.error}'));
           }

           final allResults = snapshot.data ?? [];
           
           // Filter and Process Results
           final filteredByClass = allResults.where((r) {
             if (_filterClass.isEmpty) return true;
             return r.className.toLowerCase().contains(_filterClass.toLowerCase());
           }).toList();
           
           // Group by Student ID (Latest Attempt)
           final Map<String, ResultModel> latestResultsMap = {};
           for (var result in filteredByClass) {
               if (!latestResultsMap.containsKey(result.studentId) || 
                   result.attemptNumber > latestResultsMap[result.studentId]!.attemptNumber) {
                   latestResultsMap[result.studentId] = result;
               }
           }
           final filteredResults = latestResultsMap.values.toList();
           filteredResults.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

          // Calculate Stats for Header
          double avgScore = 0;
          if (filteredResults.isNotEmpty) {
             avgScore = filteredResults.map((r) => r.score).reduce((a, b) => a + b) / filteredResults.length;
          }

          return CustomScrollView(
            slivers: [
              // Header / Hero Section
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(32, 120, 32, 40),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1B2E),
                    gradient: LinearGradient(
                      colors: [Color(0xFF2E236C), Color(0xFF433D8B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(
                                    'Quiz Results',
                                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                 ),
                                 const SizedBox(height: 8),
                                 Text(
                                   'Results for: ${widget.quiz.title}',
                                   style: const TextStyle(color: Colors.white70, fontSize: 18),
                                 ),
                               ],
                             ),
                           ),
                           // Actions Column
                           Column(
                             crossAxisAlignment: CrossAxisAlignment.end,
                             children: [
                               FilledButton.icon(
                                 onPressed: () => _showAnalytics(context, filteredResults, widget.quiz.totalMarks),
                                 icon: const Icon(Icons.bar_chart),
                                 label: const Text('Analytics'),
                                 style: FilledButton.styleFrom(
                                   backgroundColor: Colors.white, 
                                   foregroundColor: const Color(0xFF2E236C),
                                 ),
                               ),
                               const SizedBox(height: 8),
                               FilledButton.icon(
                                 onPressed: () => _showAnswerKey(context),
                                 icon: const Icon(Icons.key), 
                                 label: const Text('Answer Key'),
                                 style: FilledButton.styleFrom(
                                   backgroundColor: Colors.white.withOpacity(0.2), 
                                   foregroundColor: Colors.white,
                                 ),
                               ),
                             ],
                           ),
                         ],
                       ),
                       const SizedBox(height: 24),
                       // Quick Stats Row
                       Row(
                         children: [
                           _buildStatItem(Icons.people, '${filteredResults.length}', 'Students'),
                           const SizedBox(width: 24),
                           _buildStatItem(Icons.functions, avgScore.toStringAsFixed(1), 'Avg Score'),
                           const SizedBox(width: 24),
                           _buildStatItem(Icons.emoji_events, '${widget.quiz.totalMarks}', 'Total Marks'),
                         ],
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
                       // Search Bar
                       Container(
                         decoration: BoxDecoration(
                           color: Colors.white,
                           borderRadius: BorderRadius.circular(30),
                           boxShadow: [
                             BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                           ],
                         ),
                         child: TextField(
                           controller: _searchController,
                           decoration: InputDecoration(
                             hintText: 'Filter by Class (e.g. BSCS-4B)',
                             hintStyle: TextStyle(color: Colors.grey[400]),
                             prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                             border: InputBorder.none,
                             contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                           ),
                           onChanged: (val) => setState(() => _filterClass = val),
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
                             BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))
                           ],
                         ),
                         clipBehavior: Clip.antiAlias,
                         child: _buildResultsTable(context, filteredResults),
                       ),
                    ],
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildResultsTable(BuildContext context, List<ResultModel> filteredResults) {
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

    final isMobile = MediaQuery.of(context).size.width < 800;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 48), 
        child: DataTable(
          showCheckboxColumn: false,
          headingRowColor: WidgetStateProperty.all(const Color(0xFF2E236C)), 
          headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13), 
          dataRowMinHeight: 60,
          dataRowMaxHeight: 60,
          columnSpacing: isMobile ? 16 : 40,
          horizontalMargin: isMobile ? 10 : 30, 
          dividerThickness: 0.5,
          columns: isMobile 
            ? const [
                DataColumn(label: Text('Roll No')),
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Marks')),
                DataColumn(label: Text('Info')),
              ]
            : const [
                DataColumn(label: Text('Student Name')),
                DataColumn(label: Text('Roll No')),
                DataColumn(label: Text('Class')),
                DataColumn(label: Text('Score')),
                DataColumn(label: Text('Attempts')),
                DataColumn(label: Text('Submitted At')),
                DataColumn(label: Text('Actions')),
              ],
          rows: filteredResults.asMap().entries.map((entry) {
            final index = entry.key;
            final result = entry.value;
            final isEven = index % 2 == 0;
            
            List<DataCell> cells;
            
            if (isMobile) {
              cells = [
                DataCell(Text(result.studentRollNumber, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 12))),
                DataCell(
                  SizedBox(
                    width: 80,
                    child: Text(
                      result.studentName.isNotEmpty ? result.studentName : 'Unknown', 
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1F2937), fontSize: 12)
                    ),
                  )
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: Text(
                      '${result.score} / ${result.totalMarks}', 
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5B21B6), fontSize: 11)
                    ),
                  )
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.blueAccent),
                    onPressed: () => _showResultDetails(context, result),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                ),
              ];
            } else {
              cells = [
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
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(20)
                    ),
                    child: Text(
                      '${result.score} / ${result.totalMarks}', 
                      style: const TextStyle(
                        fontWeight: FontWeight.bold, 
                        color: Color(0xFF5B21B6),
                        fontSize: 13
                      )
                    ),
                  )
                ),
                DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: result.attemptNumber > 1 ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${result.attemptNumber}', 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: result.attemptNumber > 1 ? Colors.orange : Colors.green,
                        )
                      ),
                    )
                ),
                DataCell(Text(
                  DateFormat('MMM dd, yyyy, hh:mm a').format(result.submittedAt),
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)
                )),
                DataCell(
                    result.isCancelled 
                    ? const Text('Cancelled', style: TextStyle(color: Colors.red, fontSize: 12))
                    : IconButton(
                        icon: const Icon(Icons.replay_outlined, color: Colors.orange),
                        tooltip: 'Reset/Allow Re-attempt',
                        onPressed: () => _confirmCancelResult(context, result),
                      )
                ),
              ];
            }

            return DataRow(
              onSelectChanged: (_) {
                 context.push('/review-quiz', extra: result);
              },
              color: WidgetStateProperty.resolveWith((states) {
                return isEven ? const Color(0xFFF9FAFB) : Colors.white; 
              }),
              cells: cells,
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAnalytics(BuildContext context, List<ResultModel> results, int totalMarks) {
    if (results.isEmpty || totalMarks == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No results available for analytics.')));
      return;
    }

    // Stats Calculation
    final scores = results.map((r) => r.score).toList();
    scores.sort();
    final minScore = scores.first;
    final maxScore = scores.last;
    final avgScore = scores.reduce((a, b) => a + b) / scores.length;

    // Histogram Buckets (5 Buckets)
    final bucketSize = totalMarks / 5;
    List<int> buckets = [0, 0, 0, 0, 0];
    
    for (var score in scores) {
      int bucketIndex = (score / bucketSize).floor();
      if (bucketIndex >= 5) bucketIndex = 4; // Max score handles here
      buckets[bucketIndex]++;
    }

    final maxCount = buckets.reduce((a, b) => a > b ? a : b);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Container(
                  width: 40, height: 4, 
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  margin: const EdgeInsets.only(bottom: 24),
               ),
               Text('Detailed Analytics', style: Theme.of(context).textTheme.headlineSmall),
               const SizedBox(height: 8),
               Text('${results.length} Students Evaluated', style: TextStyle(color: Colors.grey[600])),
               const SizedBox(height: 32),
               
               // Top Stats
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                 children: [
                   _buildAnalyticStat('Lowest', '$minScore', Colors.red),
                   _buildAnalyticStat('Average', avgScore.toStringAsFixed(1), Colors.orange),
                   _buildAnalyticStat('Highest', '$maxScore', Colors.green),
                 ],
               ),
               const SizedBox(height: 40),
  
               // Histogram
               SizedBox(
                 height: 250,
                 child: Row(
                   crossAxisAlignment: CrossAxisAlignment.end,
                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                   children: List.generate(5, (index) {
                     final count = buckets[index];
                     final heightFactor = maxCount > 0 ? count / maxCount : 0.0;
                     final rangeStart = (index * bucketSize).toInt();
                     final rangeEnd = ((index + 1) * bucketSize).toInt();
                     
                     return Column(
                       mainAxisAlignment: MainAxisAlignment.end,
                       children: [
                         Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                         const SizedBox(height: 4),
                         AnimatedContainer(
                           duration: const Duration(milliseconds: 500),
                           width: 40,
                           height: 180 * heightFactor, // Reduced max height slightly to 180
                           curve: Curves.easeOut,
                           decoration: BoxDecoration(
                             color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                             borderRadius: BorderRadius.circular(8),
                           ),
                         ),
                         const SizedBox(height: 8),
                         Text('$rangeStart-$rangeEnd', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                       ],
                     );
                   }),
                 ),
               ),
               const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  void _showAnswerKey(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Answer Key'),
        content: SizedBox(
          width: 500,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: widget.quiz.questions.length,
            separatorBuilder: (c, i) => const Divider(),
            itemBuilder: (context, index) {
              final q = widget.quiz.questions[index];
              return ListTile(
                title: Text('Q${index + 1}: ${q.text}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    ...List.generate(q.options.length, (optIndex) {
                      final isCorrect = optIndex == q.correctOptionIndex;
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: isCorrect ? BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)) : null,
                        child: Row(
                          children: [
                            Icon(
                              isCorrect ? Icons.check_circle : Icons.circle_outlined, 
                              size: 16, 
                              color: isCorrect ? Colors.green : Colors.grey
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(q.options[optIndex], style: TextStyle(color: isCorrect ? Colors.green.shade900 : Colors.black87))),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
  void _confirmCancelResult(BuildContext context, ResultModel result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow Re-attempt?'),
        content: Text('Are you sure you want to cancel the result for ${result.studentName}? This will allow the student to take the quiz again. The previous score will be marked as cancelled.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirestoreService().cancelResult(result.id);
                if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Result cancelled. Student can now re-attempt.')));
                }
              } catch (e) {
                 if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                 }
              }
            },
            child: const Text('Yes, Cancel Result'),
          ),
        ],
      ),
    );
  }

  void _showResultDetails(BuildContext context, ResultModel result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Transparent for custom container
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),

            // Header: Name & Roll No
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFEDE9FE),
                  child: Text(
                    result.studentName.isNotEmpty ? result.studentName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF5B21B6)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.studentName, 
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                      ),
                      Text(
                        result.studentRollNumber, 
                        style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                // Score Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B21B6), 
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                       BoxShadow(color: const Color(0xFF5B21B6).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                    ]
                  ),
                  child: Column(
                    children: [
                      Text('${result.score}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                      Text('/ ${result.totalMarks}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                )
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Details Grid
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                 color: const Color(0xFFF9FAFB),
                 borderRadius: BorderRadius.circular(20),
                 border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Column(
                children: [
                  _buildDetailRow(Icons.class_outlined, 'Class', result.className),
                  const Divider(height: 24, thickness: 0.5),
                  _buildDetailRow(Icons.history, 'Attempt', '#${result.attemptNumber}'),
                  const Divider(height: 24, thickness: 0.5),
                  _buildDetailRow(Icons.calendar_today, 'Submitted', DateFormat('MMM dd, hh:mm a').format(result.submittedAt)),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Actions
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      context.pop();
                      context.push('/review-quiz', extra: result);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEDE9FE),
                      foregroundColor: const Color(0xFF5B21B6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.remove_red_eye, size: 20),
                    label: const Text('View Answers'),
                  ),
                ),
                if (!result.isCancelled) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFF7ED),
                        foregroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                         context.pop();
                         _confirmCancelResult(context, result);
                      },
                      icon: const Icon(Icons.replay, size: 20),
                      label: const Text('Re-attempt'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 20, color: const Color(0xFF6B7280)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            ],
          ),
        )
      ],
    );
  }
}
