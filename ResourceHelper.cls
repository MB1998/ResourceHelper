public class ResourceHelper {
    public String getOvertimeBenefitForResource(Resource__c resource){
        if(resource.isFired__c){
            return 'Error! Resource' + resource.Name + 'is fired';
        }
        
        List<TimeLog_Entry__c> timeLogs = 
            [SELECT Id, Project__c, Working_Hours__c FROM Timelog_Entry__c WHERE Start_Date__c = LAST_N_DAYS:30 AND Resource__c = :resource.Id];
        if(timeLogs.isEmpty()){
            return 'Timelogs for this month cannot be found';
        }
        
        Set<Id> projectsIds = new Set<Id>();
        for(Timelog_Entry__c timelog : timelogs){
            projectsIds.add(timelog.Project__c);
        }
            
        List<Project__c> projectsList = [SELECT Id, Overtime_Rate__c, Contract_Time__c FROM Project__c WHERE Id IN :projectsIds];
        Map<Id, Project__c> projectsMap = new Map<Id, Project__c>();
		for(Project__c project : projectsList){
			projectsMap.put(project.Id, project);
		}

        Map<Id, List<TimeLog_Entry__c>> timeLogsByProjects = new  Map<Id, List<TimeLog_Entry__c>>();

		for(Timelog_Entry__c timelog : timelogs){
			List<TimeLog_Entry__c> existedTimeLogs;
			if(TimeLogsByProjects.containsKey(timelog.Project__c)){
				existedTimeLogs = TimeLogsByProjects.get(timelog.Project__c);
			} else {
				existedTimeLogs = new List<TimeLog_Entry__c>();
			}
			existedTimeLogs.add(timelog);
			TimeLogsByProjects.put(timelog.Project__c, existedTimeLogs);
		}

		Map<Id, Decimal> overtimeWorkingHoursByProject = new Map<Id, Decimal>();
		Decimal overtimeBonusForResource = 0;

		for(Id projectId : projectsIds){
			Decimal sumOfWorkingHours = 0;
			for(TimeLog_Entry__c timelog : timeLogsByProjects.get(projectId)){
				sumOfWOrkingHours += timelog.Working_Hours__c;
			}
			Decimal ContractTimePerResource = projectsMap.get(projectId).Contract_Time__c;
			Decimal overtimeWorkingHours = sumOfWorkingHours - ContractTimePerResource;
			overtimeWorkingHoursByProject.put(projectId, overtimeWorkingHours);
			Decimal OvertimeRate = projectsMap.get(projectId).Overtime_Rate__c;
			overtimeBonusForResource += overtimeWorkingHours * OvertimeRate;
		}

		List<ResourcePermission__c> resourcePermissions = 
            [SELECT Id, Overtime_Hours__c, isOvertime__c, Project__c FROM ResourcePermission__c WHERE Resource__c = :resource.Id AND Project__c IN :projectsIds];
        
		for(ResourcePermission__c resourcePermission : resourcePermissions){
			resourcePermission.Overtime_Hours__c = overtimeWorkingHoursByProject.get(resourcePermission.Project__c);
			if(overtimeWorkingHoursByProject.get(resourcePermission.Project__c) > 0){
				resourcePermission.isOvertime__c = true;
			}
		}
		update resourcePermissions;

		return String.valueOf(overtimeBonusForResource);
    }
}
