import '../models/models.dart';

bool isUncategorizedTask(WorkItem item) =>
    !item.isDeleted &&
    item.type == WorkItemType.task &&
    item.parentId == null &&
    (item.folder.trim().isEmpty || item.folder == 'Uncategorized');
