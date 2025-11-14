import { ID } from '@datorama/akita';
import {
  IHalResourceLink,
  IHalResourceLinks,
  IFormattable,
} from 'core-app/core/state/hal-resource';

export interface IProjectHalResourceLinks extends IHalResourceLinks {
  ancestors:IHalResourceLink[];
  categories:IHalResourceLink;
  delete:IHalResourceLink;
  parent:IHalResourceLink;
  self:IHalResourceLink;
  status:IHalResourceLink;
  schema:IHalResourceLink;
  storages?:IHalResourceLink[];
}

export interface IProject {
  id:ID;
  identifier:string;
  name:string;
  public:boolean;
  active:boolean;
  statusExplanation:IFormattable;
  description:IFormattable;

  createdAt:string;
  updatedAt:string;

  // Local project attributes
  statusText?:number; // Note: Renamed from 'status' to avoid conflict with existing 'status' (ProjectStatus). Value is ID from ProjectStatusLookup
  statusLabel?:string; // Read-only label for statusText
  createdDate?:string;
  lastUpdated?:string;
  deletedDate?:string;
  lastUpdatedDate?:string;
  centroid?:string;
  externalProjectId?:string;

  _links:IProjectHalResourceLinks;
}
