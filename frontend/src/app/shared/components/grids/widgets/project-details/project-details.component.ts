import { ChangeDetectionStrategy, Component, OnInit } from '@angular/core';
import { AbstractWidgetComponent } from 'core-app/shared/components/grids/widgets/abstract-widget.component';
import { ProjectResource } from 'core-app/features/hal/resources/project-resource';
import { Observable } from 'rxjs';
import { ApiV3Service } from 'core-app/core/apiv3/api-v3.service';
import { CurrentProjectService } from 'core-app/core/current-project/current-project.service';
import { ChangeDetectorRef, inject } from '@angular/core';

@Component({
  selector: 'widget-project-details',
  templateUrl: './project-details.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: false,
})
export class WidgetProjectDetailsComponent extends AbstractWidgetComponent implements OnInit {
  private apiV3Service = inject(ApiV3Service);
  private currentProject = inject(CurrentProjectService);
  private cdRef = inject(ChangeDetectorRef);

  public project$:Observable<ProjectResource>;

  ngOnInit():void {
    if (this.currentProject.id) {
      this.project$ = this.apiV3Service.projects.id(this.currentProject.id).get();
      this.cdRef.detectChanges();
    }
  }

  get widgetName() {
    return 'Project Details';
  }
}


