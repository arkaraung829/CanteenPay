import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/children_provider.dart';
import 'report_card_pdf.dart';

/// Full report card view for a child.
class ReportCardScreen extends StatefulWidget {
  final String childId;

  const ReportCardScreen({super.key, required this.childId});

  @override
  State<ReportCardScreen> createState() => _ReportCardScreenState();
}

class _ReportCardScreenState extends State<ReportCardScreen> {
  String? _selectedTerm;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<ChildrenProvider>();
    await provider.loadReportCards(widget.childId);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Color _gradeColor(String? grade) {
    switch (grade?.toUpperCase()) {
      case 'A':
      case 'A+':
      case 'A-':
        return const Color(0xFF4CAF50);
      case 'B':
      case 'B+':
      case 'B-':
        return const Color(0xFF2196F3);
      case 'C':
      case 'C+':
      case 'C-':
        return const Color(0xFFFF9800);
      case 'D':
        return const Color(0xFFFF5722);
      case 'F':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  Color _percentageColor(double? pct) {
    if (pct == null) return AppTheme.textSecondary;
    if (pct >= 80) return const Color(0xFF4CAF50);
    if (pct >= 65) return const Color(0xFF2196F3);
    if (pct >= 40) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChildrenProvider>();
    final child = provider.children.firstWhere(
      (c) => c.id == widget.childId,
      orElse: () => StudentModel(
        id: widget.childId,
        profileId: '',
        schoolId: '',
        studentCode: '',
        fullName: 'Unknown',
      ),
    );
    final reportCards = provider.getReportCards(widget.childId);

    // Collect unique terms
    final terms = reportCards.map((rc) => rc.term).toSet().toList();
    if (_selectedTerm == null && terms.isNotEmpty) {
      _selectedTerm = terms.first;
    }

    final selectedCard = reportCards.cast<ReportCardModel?>().firstWhere(
      (rc) => rc!.term == _selectedTerm,
      orElse: () => null,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Report Card - ${child.displayName}'),
      ),
      floatingActionButton: selectedCard != null
          ? FloatingActionButton.extended(
              onPressed: () => generateAndShareReportCardPdf(
                student: child,
                reportCard: selectedCard,
                schoolName: child.schoolName ?? 'School',
              ),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Download PDF'),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : reportCards.isEmpty
              ? _buildEmptyState()
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const SizedBox(height: 16),

                    // -- Term Selector --
                    if (terms.length > 1) ...[
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: terms
                              .map((t) => ButtonSegment<String>(
                                    value: t,
                                    label: Text(t),
                                  ))
                              .toList(),
                          selected: {_selectedTerm ?? terms.first},
                          onSelectionChanged: (selection) {
                            setState(() => _selectedTerm = selection.first);
                          },
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                            selectedForegroundColor: AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (selectedCard != null) ...[
                      // -- Summary Card --
                      _buildSummaryCard(selectedCard),
                      const SizedBox(height: 20),

                      // -- Subject Scores --
                      const Text(
                        'Subject Scores',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      _buildSubjectsTable(selectedCard),
                      const SizedBox(height: 20),

                      // -- Teacher Comment --
                      if (selectedCard.teacherComment != null &&
                          selectedCard.teacherComment!.isNotEmpty) ...[
                        _buildCommentSection(
                          'Teacher Comment',
                          selectedCard.teacherComment!,
                          Icons.person,
                        ),
                        const SizedBox(height: 12),
                      ],

                      // -- Principal Comment --
                      if (selectedCard.principalComment != null &&
                          selectedCard.principalComment!.isNotEmpty) ...[
                        _buildCommentSection(
                          'Principal Comment',
                          selectedCard.principalComment!,
                          Icons.school,
                        ),
                        const SizedBox(height: 12),
                      ],

                      const SizedBox(height: 80), // space for FAB
                    ],
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No report cards yet',
            style: TextStyle(fontSize: 16, color: Colors.grey[500], fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Report cards will appear here once published.',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ReportCardModel card) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Column(
        children: [
          // Academic year + term header
          Text(
            '${card.academicYear} - ${card.term}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),

          // Percentage (big, bold, color-coded)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Percentage
              Column(
                children: [
                  Text(
                    card.percentage != null ? '${card.percentage!.toStringAsFixed(1)}%' : '--',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: _percentageColor(card.percentage),
                    ),
                  ),
                  const Text('Percentage', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),

              // Divider
              Container(height: 50, width: 1, color: Colors.grey[200]),

              // Rank
              Column(
                children: [
                  Text(
                    card.rankInClass != null ? _ordinal(card.rankInClass!) : '--',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.primary),
                  ),
                  const Text('Class Rank', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total score + Result badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Total score
              if (card.totalScore != null && card.totalFullMarks != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${card.totalScore!.toStringAsFixed(0)} / ${card.totalFullMarks}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // Result badge
              if (card.result != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: card.resultColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    card.result!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: card.resultColor,
                    ),
                  ),
                ),

              // Overall grade
              if (card.overallGrade != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _gradeColor(card.overallGrade).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Grade ${card.overallGrade}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _gradeColor(card.overallGrade),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsTable(ReportCardModel card) {
    if (card.subjects.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.shadowSm,
        ),
        child: const Center(
          child: Text('No subject scores available', style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.shadowSm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: AppTheme.primary.withValues(alpha: 0.06),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('Subject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text('Score', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                SizedBox(width: 36, child: Text('Grade', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                SizedBox(width: 28),
              ],
            ),
          ),
          // Rows
          ...card.subjects.asMap().entries.map((entry) {
            final idx = entry.key;
            final subject = entry.value;
            final isEven = idx % 2 == 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              color: isEven ? Colors.white : Colors.grey[50],
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      subject.subjectName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      subject.score != null
                          ? '${subject.score!.toStringAsFixed(0)} / ${subject.fullMarks}'
                          : '--',
                      style: const TextStyle(fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _gradeColor(subject.letterGrade).withValues(alpha: 0.15),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          subject.letterGrade ?? '-',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _gradeColor(subject.letterGrade),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Icon(
                      subject.isPassed ? Icons.check_circle : Icons.cancel,
                      size: 18,
                      color: subject.isPassed ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCommentSection(String title, String comment, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}
