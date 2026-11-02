import 'financial_context_provider.dart';

class RuleBasedFinancialAdvisor {
  static String answerQuery({
    required String query,
    required FinancialContextSummary context,
    bool isPersian = true,
  }) {
    final lower = query.toLowerCase().trim();

    // 1. Runway / Survival questions
    if (lower.contains('runway') ||
        lower.contains('دوام') ||
        lower.contains('تاب‌آوری') ||
        lower.contains('تاب اوری') ||
        lower.contains('بیکار') ||
        lower.contains('چند ماه') ||
        lower.contains('اضطراری')) {
      final months = context.runwayMonths.toStringAsFixed(1);
      if (isPersian) {
        if (context.runwayMonths >= 6.0) {
          return 'تاب‌آوری مالی (سپر نقدینگی) شما بسیار قدرتمند است! با توجه به میانگین هزینه‌های ماهانه (${context.monthlyExpense.formatted}) و موجودی نقدینگی فعلی، شما می‌توانید تا $months ماه بدون درآمد جدید زندگی کنید.';
        } else if (context.runwayMonths >= 3.0) {
          return 'تاب‌آوری مالی و وضعیت ذخیره اضطراری شما قابل قبول است ($months ماه پوشش هزینه‌ها). پیشنهاد می‌کنم برای رسیدن به حاشیه امنیت استاندارد ۶ ماه، هزینه‌های غیرضروری را کمی مهار کنید.';
        } else {
          return 'هشدار تاب‌آوری مالی: موجودی نقد شما تنها $months ماه هزینه‌های فعلی را پوشش می‌دهد. اولویت اول شما باید تقویت صندوق اضطراری و کاهش هزینه‌های متفرقه باشد.';
        }
      } else {
        return 'Your emergency runway is $months months based on current monthly burn rate (${context.monthlyExpense.formatted}).';
      }
    }

    // 2. Savings questions
    if (lower.contains('پس‌انداز') ||
        lower.contains('پس انداز') ||
        lower.contains('saving') ||
        lower.contains('سود')) {
      final rate = context.savingsRate.toStringAsFixed(1);
      if (isPersian) {
        if (context.savingsRate >= 20.0) {
          return 'عملکرد پس‌انداز شما عالی است! نرخ پس‌انداز ۳۰ روز اخیر شما $rate% بوده است که بالاتر از استاندارد طلایی ۲۰ درصد قرار دارد.';
        } else if (context.savingsRate > 0) {
          return 'نرخ پس‌انداز شما در این ماه $rate% بوده است. تلاش کنید با تنظیم بودجه در دسته‌های پرخرج، این عدد را به بالای ۲۰ درصد برسانید.';
        } else {
          return 'در ۳۰ روز اخیر هزینه‌های شما بیشتر از درآمدتان بوده است (نرخ پس‌انداز منفی). پیشنهاد می‌کنم فورا بودجه‌های ماهانه را بازبینی و فعال کنید.';
        }
      } else {
        return 'Your current savings rate is $rate%. Healthy targets are generally above 20%.';
      }
    }

    // 2.5 Balance / net worth questions
    if (lower.contains('موجودی') ||
        lower.contains('چقدر پول') ||
        lower.contains('چند دارم') ||
        lower.contains('بالانس') ||
        lower.contains('دارایی نقد') ||
        lower.contains('balance')) {
      if (isPersian) {
        final trend = context.savingsRate >= 20.0
            ? 'پس‌انداز شما هم عالی پیش می‌رود (${context.savingsRate.toStringAsFixed(1)}٪).'
            : (context.savingsRate > 0
                  ? 'نرخ پس‌انداز فعلی شما ${context.savingsRate.toStringAsFixed(1)}٪ است.'
                  : 'اما در ۳۰ روز اخیر هزینه‌ها از درآمد پیشی گرفته است.');
        return '💰 ارزش خالص دارایی نقد شما ${context.netWorth.formatted} است.\n\n'
            'در ۳۰ روز اخیر: درآمد ${context.monthlyIncome.formatted} و هزینه ${context.monthlyExpense.formatted}.\n'
            '$trend';
      }
      return 'Your current net cash worth is ${context.netWorth.formatted}. '
          'Last 30 days: income ${context.monthlyIncome.formatted}, expenses ${context.monthlyExpense.formatted}.';
    }

    // 3. Top Spending questions
    if (lower.contains('کجا') ||
        lower.contains('خرج') ||
        lower.contains('هزینه') ||
        lower.contains('expense') ||
        lower.contains('spend')) {
      if (isPersian) {
        if (context.topSpendingCategories.isEmpty) {
          return 'در ۳۰ روز اخیر هیچ هزینه‌ای ثبت نشده است.';
        }
        final topSorted = context.topSpendingCategories.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final top3 = topSorted.take(3).map((e) => '• ${e.key}').join('\n');
        return 'بیشترین بخش از هزینه‌های این ماه شما در دسته‌های زیر مصرف شده است:\n$top3\n\nکل هزینه‌های ۳۰ روز گذشته: ${context.monthlyExpense.formatted}';
      } else {
        return 'Total monthly expense is ${context.monthlyExpense.formatted}.';
      }
    }

    // 4. General Health / Overview questions
    if (lower.contains('وضعیت') ||
        lower.contains('چطوره') ||
        lower.contains('سلامت') ||
        lower.contains('health') ||
        lower.contains('score')) {
      final score = context.healthScore;
      if (isPersian) {
        String level = score >= 75
            ? 'عالی و باثبات'
            : (score >= 50 ? 'متوسط و نیازمند مدیریت' : 'هشدار و پرریسک');
        return '''
📊 گزارش جامع سلامت مالی کیفینو:
• امتیاز سلامت: $score از ۱۰۰ ($level)
• ارزش خالص دارایی نقد: ${context.netWorth.formatted}
• نرخ پس‌انداز: ${context.savingsRate.toStringAsFixed(1)}%
• تاب‌آوری مالی (Runway): ${context.runwayMonths.toStringAsFixed(1)} ماه
• بودجه‌های فراتر رفته: ${context.overspentBudgetsCount} دسته

توصیه هوشمند: ${score >= 75 ? 'دارایی‌های مازاد را به سمت سرمایه‌گذاری مولد هدایت کنید.' : 'برای جلوگیری از ناترازی مالی، سقف بودجه دسته‌های پرهزینه را سفت‌تر ببندید.'}
''';
      } else {
        return 'Your financial health score is $score/100 with a net worth of ${context.netWorth.formatted}.';
      }
    }

    // 5. Debt & Receivable questions
    if (lower.contains('بدهی') ||
        lower.contains('طلب') ||
        lower.contains('debt') ||
        lower.contains('receivable')) {
      if (isPersian) {
        return 'مجموع بدهی‌های تسویه‌نشده شما ${context.totalDebts.formatted} و مطالبات (طلب‌های) شما ${context.totalReceivables.formatted} است.';
      } else {
        return 'Total unsettled debts: ${context.totalDebts.formatted}, total receivables: ${context.totalReceivables.formatted}.';
      }
    }

    // Default response
    if (isPersian) {
      return '''
من دستیار هوشمند مالی کیفینو هستم. شما می‌توانید:
۱. تراکنش‌ها را با زبان محاوره‌ای ثبت کنید (مثلاً: "۳۵۰ تومن خرید سوپرمارکت" یا "حقوق این ماه ۵۰ میلیون تومان")
۲. درباره سلامت مالی‌تان بپرسید ("وضعیت مالیم چطوره؟" یا "چقدر دوام میارم؟")
۳. هزینه‌های عمده را تحلیل کنید ("کجاها زیاد خرج کردم؟")
''';
    } else {
      return 'I am your Kifino Financial AI. You can enter natural language transactions or ask about your runway, savings, and spending habits.';
    }
  }
}
